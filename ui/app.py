from __future__ import annotations

import json
import logging
import os
import shutil
import socket
import subprocess
import threading
import time
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
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=3)
        return out.decode().strip()
    except Exception:
        return ""


def get_tools() -> List[Dict[str, Any]]:
    tools: List[Dict[str, Any]] = []

    def add_tool(name: str, cmd: List[str], which: Optional[str] = None) -> None:
        present = shutil.which(which or cmd[0]) is not None
        version = tool_version(cmd) if present else ""
        tools.append({"name": name, "ok": bool(version), "version": version})

    add_tool("docker", ["docker", "--version"], which="docker")

    if shutil.which("docker"):
        version = tool_version(["docker", "compose", "version"])
        if not version and shutil.which("docker-compose"):
            version = tool_version(["docker-compose", "version"]) + " (legacy)"
        tools.append({"name": "docker compose", "ok": bool(version), "version": version})
    else:
        tools.append({"name": "docker compose", "ok": False, "version": ""})

    add_tool("kind", ["kind", "--version"], which="kind")
    add_tool("kubectl", ["kubectl", "version", "--client", "--short"], which="kubectl")
    add_tool("helm", ["helm", "version", "--short"], which="helm")
    add_tool("trivy", ["trivy", "--version"], which="trivy")
    add_tool("cosign", ["cosign", "version"], which="cosign")
    add_tool("syft", ["syft", "version"], which="syft")
    add_tool("ort", ["ort", "--version"], which="ort")

    return tools


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
    return jsonify({"tools": get_tools(), "timestamp": datetime.utcnow().isoformat()})


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

    result = start_run(stage)
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
