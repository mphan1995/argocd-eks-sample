from __future__ import annotations

import json
import logging
import os
import shutil
import socket
import subprocess
import threading
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
from zipfile import ZipFile, ZIP_DEFLATED

from flask import Flask, abort, jsonify, render_template, request, send_file

ROOT_DIR = Path(__file__).resolve().parents[1]
PIPELINE_DIR = ROOT_DIR / "pipeline"
OUTPUT_DIR = PIPELINE_DIR / "output"
SCRIPTS_DIR = ROOT_DIR / "scripts"

STAGES = [
    "01_build",
    "02_test",
    "03_sbom",
    "04_scan",
    "05_sign",
    "06_deploy",
    "07_verify",
]
ALLOWED_STAGES = ["all"] + STAGES

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
            "command": "python3 -m pip install --user pytest",
            "requires": ["pip3"],
            "note": "Cần pip3 trước khi cài pytest.",
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
            "command": "curl -Lo ~/.local/bin/kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64 && chmod +x ~/.local/bin/kind",
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
            "command": "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && install -m 0755 kubectl ~/.local/bin/kubectl",
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
            "command": "curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | HELM_INSTALL_DIR=~/.local/bin bash",
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
            "command": "curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/.local/bin",
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
            "hint": "Cài ORT CLI từ release chính thức (GitHub).",
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
            "command": "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ~/.local/bin",
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
            "command": "curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o ~/.local/bin/cosign && chmod +x ~/.local/bin/cosign",
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


def load_env_file() -> None:
    env_path = ROOT_DIR / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


load_env_file()

local_bin = str(Path.home() / ".local" / "bin")
if local_bin not in os.environ.get("PATH", ""):
    os.environ["PATH"] = f"{local_bin}:{os.environ.get('PATH', '')}"

UI_TOKEN = os.environ.get("UI_TOKEN", "")
REGISTRY_URL = os.environ.get("REGISTRY_URL", "localhost:5000")
IMAGE_NAME = os.environ.get("IMAGE_NAME", "sample-app")
KIND_CLUSTER_NAME = os.environ.get("KIND_CLUSTER_NAME", "local-max")

LOG_PATH = ROOT_DIR / "ui" / "ui.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_PATH), logging.StreamHandler()],
)

app = Flask(__name__)
app.config["JSON_SORT_KEYS"] = False

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

RUN_LOCK = threading.Lock()
RUN_THREADS: Dict[str, threading.Thread] = {}


def require_token() -> None:
    if not UI_TOKEN:
        return
    token = request.headers.get("X-API-Token") or request.args.get("token")
    if token != UI_TOKEN:
        abort(401)


@app.before_request
def guard_api() -> None:
    if request.path.startswith("/api/"):
        require_token()


@app.context_processor
def inject_globals() -> Dict[str, str]:
    return {"ui_token": UI_TOKEN}


def new_run_id() -> str:
    base = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    return f"{base}-{uuid.uuid4().hex[:4]}"


def safe_run_id(run_id: str) -> str:
    if "/" in run_id or ".." in run_id:
        abort(400)
    return run_id


def read_json(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}


def write_json(path: Path, data: Dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False))


def tail_text(path: Path, max_lines: int = 200) -> str:
    if not path.exists():
        return ""
    lines = path.read_text(errors="ignore").splitlines()
    if len(lines) <= max_lines:
        return "\n".join(lines)
    return "\n".join(lines[-max_lines:])


def tool_version(cmd: List[str]) -> str:
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=4)
        return out.decode().strip()
    except Exception:
        return ""


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
            version = tool_version(tool["version_cmd"]) if present else ""
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


def port_open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=1):
            return True
    except OSError:
        return False


def stack_status() -> Dict[str, Any]:
    return {
        "gitea": {"port": 3000, "ok": port_open("127.0.0.1", 3000)},
        "jenkins": {"port": 8080, "ok": port_open("127.0.0.1", 8080)},
        "registry": {"port": 5000, "ok": port_open("127.0.0.1", 5000)},
        "nexus": {"port": 8081, "ok": port_open("127.0.0.1", 8081)},
    }


def run_summary(run_dir: Path) -> Dict[str, Any]:
    ui_status = read_json(run_dir / "ui_status.json")
    base_status = read_json(run_dir / "status.json")

    state = ui_status.get("state") or base_status.get("state") or "unknown"
    stage = ui_status.get("current_stage") or base_status.get("stage") or ""
    started_at = ui_status.get("started_at") or base_status.get("updated_at") or ""
    ended_at = ui_status.get("ended_at", "")

    return {
        "run_id": run_dir.name,
        "state": state,
        "stage": stage,
        "started_at": started_at,
        "ended_at": ended_at,
    }


def list_runs() -> List[Dict[str, Any]]:
    runs: List[Dict[str, Any]] = []
    if not OUTPUT_DIR.exists():
        return runs
    for entry in OUTPUT_DIR.iterdir():
        if not entry.is_dir() or entry.name == "keys":
            continue
        runs.append(run_summary(entry))
    runs.sort(key=lambda r: r["run_id"], reverse=True)
    return runs


def run_pipeline(run_id: str, stage: str) -> None:
    run_dir = OUTPUT_DIR / run_id
    env = os.environ.copy()
    env.update(
        {
            "RUN_ID": run_id,
            "RUN_DIR": str(run_dir),
            "WORKSPACE": str(ROOT_DIR),
            "REGISTRY_URL": REGISTRY_URL,
            "IMAGE_NAME": IMAGE_NAME,
            "TAG": run_id,
            "KIND_CLUSTER_NAME": KIND_CLUSTER_NAME,
        }
    )

    stages = STAGES if stage == "all" else [stage]

    for s in stages:
        write_json(
            run_dir / "ui_status.json",
            {
                "run_id": run_id,
                "state": "running",
                "requested_stage": stage,
                "current_stage": s,
                "started_at": read_json(run_dir / "ui_status.json").get(
                    "started_at", datetime.utcnow().isoformat()
                ),
            },
        )
        script_path = PIPELINE_DIR / "stages" / f"{s}.sh"
        logging.info("Run stage %s for %s", s, run_id)
        result = subprocess.run(["bash", str(script_path)], cwd=str(ROOT_DIR), env=env)
        if result.returncode != 0:
            write_json(
                run_dir / "ui_status.json",
                {
                    "run_id": run_id,
                    "state": "failed",
                    "requested_stage": stage,
                    "current_stage": s,
                    "ended_at": datetime.utcnow().isoformat(),
                },
            )
            return

    write_json(
        run_dir / "ui_status.json",
        {
            "run_id": run_id,
            "state": "success",
            "requested_stage": stage,
            "current_stage": stages[-1],
            "ended_at": datetime.utcnow().isoformat(),
        },
    )


def start_run(stage: str) -> Dict[str, Any]:
    run_id = new_run_id()
    run_dir = OUTPUT_DIR / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    write_json(
        run_dir / "ui_status.json",
        {
            "run_id": run_id,
            "state": "running",
            "requested_stage": stage,
            "current_stage": "",
            "started_at": datetime.utcnow().isoformat(),
        },
    )

    t = threading.Thread(target=run_pipeline, args=(run_id, stage), daemon=True)
    t.start()
    with RUN_LOCK:
        RUN_THREADS[run_id] = t

    return {"run_id": run_id, "stage": stage}


def make_zip(run_dir: Path) -> Optional[Path]:
    artifacts_dir = run_dir / "artifacts"
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    zip_path = artifacts_dir / "run_artifacts.zip"
    if zip_path.exists():
        return zip_path
    with ZipFile(zip_path, "w", ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(run_dir):
            for name in files:
                full = Path(root) / name
                if full == zip_path:
                    continue
                rel = full.relative_to(run_dir)
                zf.write(full, rel)
    return zip_path


@app.get("/")
def index() -> str:
    return render_template("index.html", page="dashboard")


@app.get("/tools")
def tools() -> str:
    return render_template("tools.html", page="tools")


@app.get("/runs")
def runs() -> str:
    return render_template("runs.html", page="runs")


@app.get("/runs/<run_id>")
def run_detail(run_id: str) -> str:
    safe_run_id(run_id)
    return render_template("run_detail.html", page="run-detail", run_id=run_id)


@app.get("/api/tools")
def api_tools() -> Any:
    tools = get_tools()
    return jsonify(
        {
            "tools": tools,
            "summary": summarize_tools(tools),
            "timestamp": datetime.utcnow().isoformat(),
        }
    )


@app.post("/api/tools/install")
def api_tools_install() -> Any:
    payload = request.get_json(silent=True) or request.form
    tool_id = payload.get("tool_id", "")
    tool = TOOLS_INDEX.get(tool_id)
    if not tool:
        return jsonify({"error": "tool not found"}), 404

    install = tool.get("install", {})
    if install.get("mode") != "script":
        return jsonify({"error": "tool is not installable"}), 400

    script_path = SCRIPTS_DIR / "install_tool.sh"
    if not script_path.exists():
        return jsonify({"error": "installer script missing"}), 500

    result = subprocess.run(
        ["bash", str(script_path), tool_id],
        cwd=str(ROOT_DIR),
        capture_output=True,
        text=True,
    )
    output = "\n".join([result.stdout.strip(), result.stderr.strip()]).strip()
    return jsonify(
        {
            "ok": result.returncode == 0,
            "exit_code": result.returncode,
            "output": output[-4000:],
        }
    )


@app.get("/api/stack")
def api_stack() -> Any:
    return jsonify({"services": stack_status()})


@app.post("/api/stack/start")
def api_stack_start() -> Any:
    try:
        subprocess.Popen(["bash", str(SCRIPTS_DIR / "start_stack.sh")], cwd=str(ROOT_DIR))
        return jsonify({"ok": True})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.post("/api/stack/stop")
def api_stack_stop() -> Any:
    try:
        subprocess.Popen(["bash", str(SCRIPTS_DIR / "stop_stack.sh")], cwd=str(ROOT_DIR))
        return jsonify({"ok": True})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.post("/api/run")
def api_run() -> Any:
    payload = request.get_json(silent=True) or request.form
    stage = payload.get("stage", "all")
    if stage not in ALLOWED_STAGES:
        return jsonify({"error": "invalid stage"}), 400

    with RUN_LOCK:
        running = [r for r in list_runs() if r.get("state") == "running"]
        if running:
            return jsonify({"error": "pipeline is running"}), 409

    missing = missing_tools_for_stage(stage)
    if missing["required"]:
        return (
            jsonify(
                {
                    "error": "missing tools",
                    "missing": missing,
                    "message": "Thiếu tool bắt buộc, hãy cài trước khi chạy.",
                }
            ),
            422,
        )

    result = start_run(stage)
    if missing["optional"]:
        result["missing_optional"] = missing["optional"]
    return jsonify(result)


@app.get("/api/runs")
def api_runs() -> Any:
    return jsonify({"runs": list_runs()})


@app.get("/api/runs/<run_id>")
def api_run_detail(run_id: str) -> Any:
    safe_run_id(run_id)
    run_dir = OUTPUT_DIR / run_id
    if not run_dir.exists():
        return jsonify({"error": "run not found"}), 404

    logs: Dict[str, str] = {}
    log_dir = run_dir / "logs"
    if log_dir.exists():
        for log_file in sorted(log_dir.glob("*.log")):
            stage_name = log_file.stem
            logs[stage_name] = tail_text(log_file)

    data = run_summary(run_dir)
    data.update({"logs": logs})
    return jsonify(data)


@app.get("/api/runs/<run_id>/download")
def api_run_download(run_id: str) -> Any:
    safe_run_id(run_id)
    run_dir = OUTPUT_DIR / run_id
    if not run_dir.exists():
        return jsonify({"error": "run not found"}), 404

    zip_path = make_zip(run_dir)
    if not zip_path:
        return jsonify({"error": "artifact not found"}), 404
    return send_file(zip_path, as_attachment=True, download_name=zip_path.name)


if __name__ == "__main__":
    host = os.environ.get("UI_BIND", "127.0.0.1")
    port = int(os.environ.get("UI_PORT", "5001"))
    app.run(host=host, port=port, debug=bool(os.environ.get("FLASK_DEBUG")))
