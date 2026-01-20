from __future__ import annotations

import logging
import os
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
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


def update_path() -> None:
    local_bin = str(Path.home() / ".local" / "bin")
    current_path = os.environ.get("PATH", "")
    if local_bin not in current_path:
        os.environ["PATH"] = f"{local_bin}:{current_path}"

    install_dir_env = os.environ.get("INSTALL_DIR", "").strip()
    if install_dir_env:
        expanded = os.path.expanduser(install_dir_env)
        if expanded not in os.environ.get("PATH", ""):
            os.environ["PATH"] = f"{expanded}:{os.environ.get('PATH', '')}"


load_env_file()
update_path()

UI_TOKEN = os.environ.get("UI_TOKEN", "")
REGISTRY_URL = os.environ.get("REGISTRY_URL", "localhost:5000")
IMAGE_NAME = os.environ.get("IMAGE_NAME", "sample-app")
KIND_CLUSTER_NAME = os.environ.get("KIND_CLUSTER_NAME", "local-max")

LOG_PATH = ROOT_DIR / "ui" / "ui.log"


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(LOG_PATH), logging.StreamHandler()],
    )


configure_logging()
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
