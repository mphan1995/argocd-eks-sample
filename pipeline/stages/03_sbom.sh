#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

STAGE_NAME="03_sbom"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../base_stage.sh
source "${PIPELINE_DIR}/base_stage.sh"

init_stage "${STAGE_NAME}"

trap 'finalize_stage "${STAGE_NAME}" "failed"' ERR

APP_DIR="${WORKSPACE}/app/sample-app"
SBOM_PATH="${RUN_DIR}/data/sbom.json"
IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:${TAG}"

if command -v syft >/dev/null 2>&1; then
  log "Generate SBOM with syft"
  if command -v docker >/dev/null 2>&1 && docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
    syft "${IMAGE_TAG}" -o json > "${SBOM_PATH}"
  else
    syft "dir:${APP_DIR}" -o json > "${SBOM_PATH}"
  fi
elif command -v ort >/dev/null 2>&1; then
  log "ORT có sẵn nhưng chưa cấu hình; tạo placeholder"
  cat > "${SBOM_PATH}" <<EOF_SBOM
{
  "tool": "ort",
  "note": "ORT detected but not configured; placeholder SBOM",
  "image": "${IMAGE_TAG}"
}
EOF_SBOM
else
  log "Không có syft/ort; tạo placeholder"
  cat > "${SBOM_PATH}" <<EOF_SBOM
{
  "tool": "none",
  "note": "syft/ort not found; placeholder SBOM",
  "image": "${IMAGE_TAG}"
}
EOF_SBOM
fi

finalize_stage "${STAGE_NAME}" "success"
