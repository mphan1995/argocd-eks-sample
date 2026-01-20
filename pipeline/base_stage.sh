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

json_escape() {
  printf "%s" "$1" | sed 's/\"/\\\"/g'
}

write_run_meta() {
  local meta_file="$1"
  if [ -f "$meta_file" ]; then
    return
  fi
  cat > "$meta_file" <<EOF_META
{
  "run_id": "$(basename "${RUN_DIR}")",
  "created_at": "$(date -Iseconds)",
  "workspace": "$(json_escape "${WORKSPACE}")",
  "image": "$(json_escape "${REGISTRY_URL}/${IMAGE_NAME}:${TAG}")",
  "host": "$(json_escape "$(hostname)")",
  "kernel": "$(json_escape "$(uname -sr)")"
}
EOF_META
}

record_tool_versions() {
  local tools_file="$1"
  if [ -f "$tools_file" ]; then
    return
  fi
  local docker_ver compose_ver kind_ver kubectl_ver helm_ver trivy_ver cosign_ver syft_ver python_ver git_ver

  docker_ver="$(command -v docker >/dev/null 2>&1 && docker --version || true)"
  if command -v docker >/dev/null 2>&1; then
    compose_ver="$(docker compose version 2>/dev/null || true)"
    if [ -z "$compose_ver" ] && command -v docker-compose >/dev/null 2>&1; then
      compose_ver="$(docker-compose version 2>/dev/null || true)"
    fi
  else
    compose_ver=""
  fi
  kind_ver="$(command -v kind >/dev/null 2>&1 && kind --version || true)"
  kubectl_ver="$(command -v kubectl >/dev/null 2>&1 && kubectl version --client --short 2>/dev/null || true)"
  helm_ver="$(command -v helm >/dev/null 2>&1 && helm version --short 2>/dev/null || true)"
  trivy_ver="$(command -v trivy >/dev/null 2>&1 && trivy --version 2>/dev/null || true)"
  cosign_ver="$(command -v cosign >/dev/null 2>&1 && cosign version 2>/dev/null || true)"
  syft_ver="$(command -v syft >/dev/null 2>&1 && syft version 2>/dev/null || true)"
  python_ver="$(command -v python3 >/dev/null 2>&1 && python3 --version 2>/dev/null || true)"
  git_ver="$(command -v git >/dev/null 2>&1 && git --version 2>/dev/null || true)"

  cat > "$tools_file" <<EOF_TOOLS
{
  "docker": "$(json_escape "${docker_ver}")",
  "docker_compose": "$(json_escape "${compose_ver}")",
  "kind": "$(json_escape "${kind_ver}")",
  "kubectl": "$(json_escape "${kubectl_ver}")",
  "helm": "$(json_escape "${helm_ver}")",
  "trivy": "$(json_escape "${trivy_ver}")",
  "cosign": "$(json_escape "${cosign_ver}")",
  "syft": "$(json_escape "${syft_ver}")",
  "python3": "$(json_escape "${python_ver}")",
  "git": "$(json_escape "${git_ver}")"
}
EOF_TOOLS
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

  STAGE_START_TS="$(date +%s)"
  export STAGE_START_TS

  log "Stage: ${stage_name}"
  log "RUN_DIR=${RUN_DIR}"
  log "IMAGE=${REGISTRY_URL}/${IMAGE_NAME}:${TAG}"

  write_run_meta "${RUN_DIR}/meta.json"
  record_tool_versions "${RUN_DIR}/tools.json"

  write_status "${stage_name}" "running"
}

write_status() {
  local stage="$1"
  local state="$2"
  local duration=0
  if [ -n "${STAGE_START_TS:-}" ]; then
    duration=$(( $(date +%s) - STAGE_START_TS ))
  fi
  cat > "${RUN_DIR}/status.json" <<EOF_STATUS
{
  "run_id": "$(basename "${RUN_DIR}")",
  "stage": "${stage}",
  "state": "${state}",
  "updated_at": "$(date -Iseconds)",
  "duration_sec": ${duration}
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
