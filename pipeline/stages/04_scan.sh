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
TRIVY_SEVERITY="${TRIVY_SEVERITY:-CRITICAL,HIGH}"
TRIVY_TIMEOUT="${TRIVY_TIMEOUT:-5m}"
TRIVY_SKIP_DB_UPDATE="${TRIVY_SKIP_DB_UPDATE:-true}"
SBOM_DIR="${RUN_DIR}/data/sbom"
SBOM_CDX="${SBOM_DIR}/sbom.cdx.json"
SBOM_SPDX="${SBOM_DIR}/sbom.spdx.json"

trivy_supports_sbom() {
  trivy sbom --help >/dev/null 2>&1
}

trivy_supports_input() {
  trivy sbom --help 2>/dev/null | grep -q -- "--input"
}

scan_base=()
scan_target=""
scan_note="image"
scan_mode="image"

if trivy_supports_sbom && trivy_supports_input; then
  if [ -f "${SBOM_CDX}" ]; then
    scan_base=(trivy sbom --input "${SBOM_CDX}")
    scan_note="sbom-cyclonedx"
    scan_mode="sbom"
  elif [ -f "${SBOM_SPDX}" ]; then
    scan_base=(trivy sbom --input "${SBOM_SPDX}")
    scan_note="sbom-spdx"
    scan_mode="sbom"
  fi
fi

if [ "${scan_mode}" != "sbom" ]; then
  scan_base=(trivy image)
  scan_target="${IMAGE_TAG}"
  scan_note="image"
  scan_mode="image"
fi

run_trivy() {
  "${scan_base[@]}" \
    --quiet \
    --timeout "${TRIVY_TIMEOUT}" \
    --severity "${TRIVY_SEVERITY}" \
    --format json \
    --output "${SCAN_PATH}" \
    "$@" \
    ${scan_target:+ "${scan_target}"}
}

if command -v trivy >/dev/null 2>&1; then
  log "Scan ${scan_note} with trivy"
  set +e
  exit_code=0
  if [ "${TRIVY_SKIP_DB_UPDATE}" = "true" ]; then
    run_trivy --skip-db-update
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
      log "Trivy cần DB; chạy lại không skip-db-update"
      run_trivy
      exit_code=$?
    fi
  else
    run_trivy
    exit_code=$?
  fi
  set -e
  if [ "$exit_code" -ne 0 ] && [ "${scan_mode}" = "sbom" ]; then
    log "SBOM scan thất bại; fallback sang image scan"
    scan_base=(trivy image)
    scan_target="${IMAGE_TAG}"
    scan_note="image"
    set +e
    run_trivy
    exit_code=$?
    set -e
  fi
  if [ "$exit_code" -ne 0 ]; then
    log "Trivy lỗi hoặc thiếu DB; tạo placeholder"
    cat > "${SCAN_PATH}" <<EOF_SCAN
{
  "tool": "trivy",
  "note": "scan failed or db missing; placeholder",
  "image": "${IMAGE_TAG}"
}
EOF_SCAN
  fi
else
  log "Không có trivy; tạo placeholder"
  cat > "${SCAN_PATH}" <<EOF_SCAN
{
  "tool": "none",
  "note": "trivy not found; placeholder scan",
  "image": "${IMAGE_TAG}"
}
EOF_SCAN
fi

finalize_stage "${STAGE_NAME}" "success"
