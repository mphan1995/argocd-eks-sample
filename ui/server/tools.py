from __future__ import annotations

import re
import shutil
import subprocess
from typing import Any, Dict, List

from .config import STAGES

TOOLS_CATALOG: List[Dict[str, Any]] = [
    {
        "id": "docker",
        "name": "Docker Engine",
        "binary": "docker",
        "version_cmd": ["docker", "--version"],
        "required_for": ["01_build", "06_deploy"],
        "critical": True,
        "recommended": "24.x+",
        "install": {
            "mode": "manual",
            "hint": "Cài Docker Desktop và bật WSL2 integration.",
        },
    },
    {
        "id": "docker_compose",
        "name": "Docker Compose",
        "binary": "docker",
        "version_cmd": ["docker", "compose", "version"],
        "required_for": ["stack"],
        "critical": True,
        "recommended": "v2.x",
        "install": {
            "mode": "manual",
            "hint": "Cài Docker Desktop hoặc docker-compose plugin.",
        },
    },
    {
        "id": "python3",
        "name": "Python 3",
        "binary": "python3",
        "version_cmd": ["python3", "--version"],
        "required_for": ["02_test", "07_verify"],
        "critical": True,
        "recommended": "3.10+",
        "install": {
            "mode": "manual",
            "hint": "sudo apt-get install -y python3 python3-venv python3-pip",
        },
    },
    {
        "id": "pip3",
        "name": "pip",
        "binary": "pip3",
        "version_cmd": ["pip3", "--version"],
        "required_for": ["02_test"],
        "critical": False,
        "recommended": "23.x+",
        "install": {
            "mode": "manual",
            "hint": "sudo apt-get install -y python3-pip",
        },
    },
    {
        "id": "pytest",
        "name": "pytest",
        "binary": "pytest",
        "version_cmd": ["pytest", "--version"],
        "required_for": ["02_test"],
        "critical": False,
        "recommended": "8.x",
        "install": {
            "mode": "script",
            "command": "bash scripts/install_tool.sh pytest",
            "requires": ["python3", "pip3"],
            "note": "Nếu đang chạy trong venv, installer sẽ cài vào venv hiện tại.",
        },
    },
    {
        "id": "kind",
        "name": "kind",
        "binary": "kind",
        "version_cmd": ["kind", "--version"],
        "required_for": ["06_deploy"],
        "critical": True,
        "recommended": "v0.23+",
        "install": {
            "mode": "script",
            "command": "bash scripts/install_tool.sh kind",
            "requires": ["curl"],
        },
    },
    {
        "id": "kubectl",
        "name": "kubectl",
        "binary": "kubectl",
        "version_cmd": ["kubectl", "version", "--client", "--short"],
        "required_for": ["06_deploy", "07_verify"],
        "critical": True,
        "recommended": "v1.29+",
        "install": {
            "mode": "script",
            "command": "bash scripts/install_tool.sh kubectl",
            "requires": ["curl"],
        },
    },
    {
        "id": "helm",
        "name": "Helm",
        "binary": "helm",
        "version_cmd": ["helm", "version", "--short"],
        "required_for": ["06_deploy"],
        "critical": True,
        "recommended": "v3.14+",
        "install": {
            "mode": "script",
            "command": "bash scripts/install_tool.sh helm",
            "requires": ["curl"],
        },
    },
    {
        "id": "syft",
        "name": "Syft (SBOM)",
        "binary": "syft",
        "version_cmd": ["syft", "version"],
        "required_for": ["03_sbom"],
        "critical": False,
        "recommended": "v1.x",
        "install": {
            "mode": "script",
            "command": "bash scripts/install_tool.sh syft",
            "requires": ["curl"],
        },
    },
    {
        "id": "ort",
        "name": "ORT (SBOM)",
        "binary": "ort",
        "version_cmd": ["ort", "--version"],
        "required_for": ["03_sbom"],
        "critical": False,
        "recommended": "latest",
        "install": {
            "mode": "manual",
            "hint": "Tải ORT CLI từ https://github.com/oss-review-toolkit/ort/releases, giải nén và add vào PATH. Yêu cầu Java 17+.",
        },
    },
    {
        "id": "trivy",
        "name": "Trivy",
        "binary": "trivy",
        "version_cmd": ["trivy", "--version"],
        "required_for": ["04_scan"],
        "critical": False,
        "recommended": "v0.50+",
        "install": {
            "mode": "script",
            "command": "bash scripts/install_tool.sh trivy",
            "requires": ["curl"],
        },
    },
    {
        "id": "cosign",
        "name": "Cosign",
        "binary": "cosign",
        "version_cmd": ["cosign", "version"],
        "required_for": ["05_sign"],
        "critical": False,
        "recommended": "v2.x",
        "install": {
            "mode": "script",
            "command": "bash scripts/install_tool.sh cosign",
            "requires": ["curl"],
        },
    },
    {
        "id": "curl",
        "name": "curl",
        "binary": "curl",
        "version_cmd": ["curl", "--version"],
        "required_for": ["07_verify"],
        "critical": False,
        "recommended": "7.x+",
        "install": {
            "mode": "manual",
            "hint": "sudo apt-get install -y curl",
        },
    },
]

TOOLS_INDEX = {tool["id"]: tool for tool in TOOLS_CATALOG}


def tool_version(cmd: List[str]) -> str:
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=4,
            check=False,
        )
        output = (result.stdout or "") + (result.stderr or "")
        return output.strip()
    except Exception:
        return ""


def extract_semver(text: str) -> str:
    match = re.search(r"v?\d+\.\d+\.\d+(?:[-+][\w.]+)?", text)
    return match.group(0) if match else ""


def normalize_version(output: str) -> str:
    text = output.strip()
    if not text:
        return ""
    lower = text.lower()
    if ("error" in lower or "unknown" in lower) and not extract_semver(text):
        return ""
    return text


def resolve_kubectl_version() -> str:
    output = tool_version(["kubectl", "version", "--client", "--short"])
    output = normalize_version(output)
    if output:
        return output
    output = tool_version(["kubectl", "version", "--client"])
    return normalize_version(output)


def resolve_docker_compose() -> Dict[str, Any]:
    if not shutil.which("docker"):
        return {"ok": False, "version": "", "binary": "docker compose"}

    version = tool_version(["docker", "compose", "version"])
    binary = "docker compose"
    if not version and shutil.which("docker-compose"):
        legacy = tool_version(["docker-compose", "version"])
        if legacy:
            version = f"{legacy} (legacy)"
            binary = "docker-compose"
    return {"ok": bool(version), "version": version, "binary": binary}


def get_tools() -> List[Dict[str, Any]]:
    tools: List[Dict[str, Any]] = []

    for tool in TOOLS_CATALOG:
        install = tool.get("install", {})
        install_mode = install.get("mode", "manual")
        install_command = install.get("command", "")
        install_hint = install.get("hint", "")
        install_requires = install.get("requires", [])
        install_note = install.get("note", "")

        if tool["id"] == "docker_compose":
            compose = resolve_docker_compose()
            ok = compose["ok"]
            version = compose["version"]
            binary = compose["binary"]
        else:
            binary = tool["binary"]
            present = shutil.which(binary) is not None
            if tool["id"] == "kubectl" and present:
                version = resolve_kubectl_version()
            else:
                version = normalize_version(tool_version(tool["version_cmd"])) if present else ""
            ok = bool(version)

        tools.append(
            {
                "id": tool["id"],
                "name": tool["name"],
                "binary": binary,
                "ok": ok,
                "version": version,
                "recommended": tool.get("recommended", ""),
                "critical": tool.get("critical", False),
                "required_for": tool.get("required_for", []),
                "installable": install_mode == "script",
                "install_command": install_command,
                "install_hint": install_hint,
                "install_requires": install_requires,
                "install_note": install_note,
            }
        )

    return tools


def summarize_tools(tools: List[Dict[str, Any]]) -> Dict[str, Any]:
    missing_required = [t for t in tools if t["critical"] and not t["ok"]]
    missing_optional = [t for t in tools if not t["critical"] and not t["ok"]]
    return {
        "total": len(tools),
        "missing_required": len(missing_required),
        "missing_optional": len(missing_optional),
    }


def missing_tools_for_stage(stage: str) -> Dict[str, List[Dict[str, Any]]]:
    stage_list = STAGES if stage == "all" else [stage]
    tools = get_tools()
    missing_required: List[Dict[str, Any]] = []
    missing_optional: List[Dict[str, Any]] = []

    for tool in tools:
        required_for = tool.get("required_for", [])
        if not any(s in required_for for s in stage_list):
            continue
        if tool["critical"]:
            if not tool["ok"]:
                missing_required.append(tool)
        else:
            if not tool["ok"]:
                missing_optional.append(tool)

    return {"required": missing_required, "optional": missing_optional}
