#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${PIPELINE_DIR}/output"

log() {
  printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Thiếu tool: $1"
    return 1
  fi
}

init_stage() {
  local stage_name="$1"
  local run_id

  if [ -n "${RUN_DIR:-}" ] && [ -z "${RUN_ID:-}" ]; then
    run_id="$(basename "${RUN_DIR}")"
  else
    run_id="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
  fi
  RUN_DIR="${RUN_DIR:-${OUTPUT_DIR}/${run_id}}"
  WORKSPACE="${WORKSPACE:-$(cd "${PIPELINE_DIR}/.." && pwd)}"
  REGISTRY_URL="${REGISTRY_URL:-localhost:5000}"
  IMAGE_NAME="${IMAGE_NAME:-sample-app}"
  TAG="${TAG:-local}"

  export RUN_ID="$run_id"
  export RUN_DIR WORKSPACE REGISTRY_URL IMAGE_NAME TAG

  mkdir -p "${RUN_DIR}/logs" "${RUN_DIR}/artifacts" "${RUN_DIR}/data"

  LOG_FILE="${RUN_DIR}/logs/${stage_name}.log"
  export LOG_FILE

  exec > >(tee -a "${LOG_FILE}") 2>&1

  log "Stage: ${stage_name}"
  log "RUN_DIR=${RUN_DIR}"
  log "IMAGE=${REGISTRY_URL}/${IMAGE_NAME}:${TAG}"

  write_status "${stage_name}" "running"
}

write_status() {
  local stage="$1"
  local state="$2"
  cat > "${RUN_DIR}/status.json" <<EOF_STATUS
{
  "run_id": "$(basename "${RUN_DIR}")",
  "stage": "${stage}",
  "state": "${state}",
  "updated_at": "$(date -Iseconds)"
}
EOF_STATUS
}

finalize_stage() {
  local stage="$1"
  local state="${2:-success}"
  write_status "${stage}" "${state}"
  package_run
}

package_run() {
  local archive="${RUN_DIR}/artifacts/run_artifacts.zip"

  if command -v python3 >/dev/null 2>&1; then
    ZIP_PATH="${archive}" RUN_DIR="${RUN_DIR}" python3 - <<'PY'
import os
import zipfile

zip_path = os.environ["ZIP_PATH"]
run_dir = os.environ["RUN_DIR"]

with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for root, _, files in os.walk(run_dir):
        for name in files:
            full = os.path.join(root, name)
            if os.path.abspath(full) == os.path.abspath(zip_path):
                continue
            rel = os.path.relpath(full, run_dir)
            zf.write(full, rel)
print(f"Zip created: {zip_path}")
PY
  elif command -v zip >/dev/null 2>&1; then
    (cd "${RUN_DIR}" && zip -qr "${archive}" .)
  else
    log "Không có zip/python3 để tạo artifact."
  fi
}
