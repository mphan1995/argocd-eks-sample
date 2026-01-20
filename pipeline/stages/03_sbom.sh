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
IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:${TAG}"
SBOM_DIR="${RUN_DIR}/data/sbom"
SBOM_SPDX="${SBOM_DIR}/sbom.spdx.json"
SBOM_CDX="${SBOM_DIR}/sbom.cdx.json"
SBOM_SYFT="${SBOM_DIR}/sbom.syft.json"

mkdir -p "${SBOM_DIR}"

TARGET="dir:${APP_DIR}"
if command -v docker >/dev/null 2>&1 && docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
  TARGET="${IMAGE_TAG}"
fi

if command -v syft >/dev/null 2>&1; then
  log "Generate SBOM (SPDX + CycloneDX) with syft"
  set +e
  syft "${TARGET}" -o spdx-json > "${SBOM_SPDX}"
  spdx_status=$?
  syft "${TARGET}" -o cyclonedx-json > "${SBOM_CDX}"
  cdx_status=$?
  syft "${TARGET}" -o json > "${SBOM_SYFT}"
  syft_status=$?
  set -e
  if [ "${spdx_status}" -ne 0 ] || [ "${cdx_status}" -ne 0 ] || [ "${syft_status}" -ne 0 ]; then
    log "Syft lỗi; ghi placeholder"
    rm -f "${SBOM_SPDX}" "${SBOM_CDX}" "${SBOM_SYFT}"
    spdx_status=1
  fi
else
  log "Không có syft; tạo placeholder SPDX/CycloneDX"
  spdx_status=1
fi

if [ "${spdx_status:-1}" -ne 0 ]; then
  cat > "${SBOM_SPDX}" <<EOF_SBOM
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "sample-app",
  "documentNamespace": "https://local.example/sbom/${TAG}",
  "creationInfo": {
    "created": "$(date -Iseconds)",
    "creators": ["Tool: placeholder"]
  },
  "packages": [],
  "note": "syft not found; placeholder SPDX"
}
EOF_SBOM
  cat > "${SBOM_CDX}" <<EOF_SBOM
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.5",
  "version": 1,
  "metadata": {
    "timestamp": "$(date -Iseconds)",
    "tools": [
      { "vendor": "local", "name": "placeholder", "version": "0.1" }
    ],
    "component": {
      "type": "application",
      "name": "sample-app",
      "version": "${TAG}"
    }
  },
  "components": [],
  "note": "syft not found; placeholder CycloneDX"
}
EOF_SBOM
  cat > "${SBOM_SYFT}" <<EOF_SBOM
{
  "tool": "none",
  "note": "syft not found; placeholder syft json",
  "image": "${IMAGE_TAG}"
}
EOF_SBOM
fi

finalize_stage "${STAGE_NAME}" "success"
