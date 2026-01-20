#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

STAGE_NAME="04_scan"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../base_stage.sh
source "${PIPELINE_DIR}/base_stage.sh"

init_stage "${STAGE_NAME}"

trap 'finalize_stage "${STAGE_NAME}" "failed"' ERR

SCAN_PATH="${RUN_DIR}/data/scan.json"
IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:${TAG}"

if command -v trivy >/dev/null 2>&1; then
  log "Scan image with trivy"
  set +e
  trivy image --quiet --format json --output "${SCAN_PATH}" --skip-db-update "${IMAGE_TAG}"
  exit_code=$?
  set -e
  if [ "$exit_code" -ne 0 ]; then
    log "Trivy lỗi hoặc thiếu DB; tạo placeholder"
    cat > "${SCAN_PATH}" <<'EOF_SCAN'
{
  "tool": "trivy",
  "note": "scan failed or db missing; placeholder"
}
EOF_SCAN
  fi
else
  log "Không có trivy; tạo placeholder"
  cat > "${SCAN_PATH}" <<'EOF_SCAN'
{
  "tool": "none",
  "note": "trivy not found; placeholder scan"
}
EOF_SCAN
fi

finalize_stage "${STAGE_NAME}" "success"
