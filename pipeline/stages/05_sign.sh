#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

STAGE_NAME="05_sign"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../base_stage.sh
source "${PIPELINE_DIR}/base_stage.sh"

init_stage "${STAGE_NAME}"

trap 'finalize_stage "${STAGE_NAME}" "failed"' ERR

SIGN_PATH="${RUN_DIR}/data/sign.txt"
IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:${TAG}"
KEY_DIR="${PIPELINE_DIR}/output/keys"
KEY_PREFIX="${KEY_DIR}/cosign"

if command -v cosign >/dev/null 2>&1; then
  log "Cosign available; generate keypair if missing"
  mkdir -p "${KEY_DIR}"
  if [ ! -f "${KEY_PREFIX}.key" ]; then
    export COSIGN_PASSWORD="${COSIGN_PASSWORD:-localpass}"
    (cd "${KEY_DIR}" && cosign generate-key-pair)
  fi
  export COSIGN_PASSWORD="${COSIGN_PASSWORD:-localpass}"
  cosign sign --key "${KEY_PREFIX}.key" --tlog-upload=false --allow-insecure-registry "${IMAGE_TAG}"
  echo "signed: ${IMAGE_TAG}" > "${SIGN_PATH}"
else
  log "Không có cosign; tạo placeholder"
  cat > "${SIGN_PATH}" <<'EOF_SIGN'
cosign not found; signature skipped
EOF_SIGN
fi

finalize_stage "${STAGE_NAME}" "success"
