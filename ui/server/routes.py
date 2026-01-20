from __future__ import annotations

import subprocess
from datetime import datetime
from typing import Any, Dict

from flask import Blueprint, abort, jsonify, render_template, request, send_file

from .config import ALLOWED_STAGES, OUTPUT_DIR, ROOT_DIR, SCRIPTS_DIR
from .runs import (
    RUN_LOCK,
    delete_run,
    list_runs,
    make_zip,
    run_summary,
    start_run,
    tail_text,
    validate_run_id,
)
from .stack import stack_status
from .tools import TOOLS_INDEX, get_tools, missing_tools_for_stage, summarize_tools

pages_bp = Blueprint("pages", __name__)
api_bp = Blueprint("api", __name__, url_prefix="/api")


@pages_bp.get("/")
def index() -> str:
    return render_template("index.html", page="dashboard")


@pages_bp.get("/tools")
def tools() -> str:
    return render_template("tools.html", page="tools")


@pages_bp.get("/runs")
def runs() -> str:
    return render_template("runs.html", page="runs")


@pages_bp.get("/runs/<run_id>")
def run_detail(run_id: str) -> str:
    try:
        validate_run_id(run_id)
    except ValueError:
        abort(400)
    return render_template("run_detail.html", page="run-detail", run_id=run_id)


@api_bp.get("/tools")
def api_tools() -> Any:
    tools = get_tools()
    return jsonify(
        {
            "tools": tools,
            "summary": summarize_tools(tools),
            "timestamp": datetime.utcnow().isoformat(),
        }
    )


@api_bp.post("/tools/install")
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


@api_bp.get("/stack")
def api_stack() -> Any:
    return jsonify({"services": stack_status()})


@api_bp.post("/stack/start")
def api_stack_start() -> Any:
    try:
        subprocess.Popen(["bash", str(SCRIPTS_DIR / "start_stack.sh")], cwd=str(ROOT_DIR))
        return jsonify({"ok": True})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@api_bp.post("/stack/stop")
def api_stack_stop() -> Any:
    try:
        subprocess.Popen(["bash", str(SCRIPTS_DIR / "stop_stack.sh")], cwd=str(ROOT_DIR))
        return jsonify({"ok": True})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@api_bp.post("/run")
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


@api_bp.get("/runs")
def api_runs() -> Any:
    return jsonify({"runs": list_runs()})


@api_bp.get("/runs/<run_id>")
def api_run_detail(run_id: str) -> Any:
    try:
        validate_run_id(run_id)
    except ValueError:
        abort(400)
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


@api_bp.get("/runs/<run_id>/download")
def api_run_download(run_id: str) -> Any:
    try:
        validate_run_id(run_id)
    except ValueError:
        abort(400)
    run_dir = OUTPUT_DIR / run_id
    if not run_dir.exists():
        return jsonify({"error": "run not found"}), 404

    zip_path = make_zip(run_dir)
    if not zip_path:
        return jsonify({"error": "artifact not found"}), 404
    return send_file(zip_path, as_attachment=True, download_name=zip_path.name)


@api_bp.post("/runs/<run_id>/delete")
def api_run_delete(run_id: str) -> Any:
    try:
        deleted = delete_run(run_id)
    except ValueError:
        abort(400)
    if not deleted:
        return jsonify({"error": "run not found"}), 404
    return jsonify({"ok": True})
