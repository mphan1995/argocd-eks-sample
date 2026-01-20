from __future__ import annotations

import json
import logging
import os
import threading
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
from zipfile import ZIP_DEFLATED, ZipFile

import subprocess

from .config import (
    IMAGE_NAME,
    KIND_CLUSTER_NAME,
    OUTPUT_DIR,
    PIPELINE_DIR,
    REGISTRY_URL,
    ROOT_DIR,
    STAGES,
)

RUN_LOCK = threading.Lock()
RUN_THREADS: Dict[str, threading.Thread] = {}


def new_run_id() -> str:
    base = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    return f"{base}-{uuid.uuid4().hex[:4]}"


def validate_run_id(run_id: str) -> None:
    if "/" in run_id or ".." in run_id:
        raise ValueError("invalid run id")


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
