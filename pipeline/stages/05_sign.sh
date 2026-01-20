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
STRICT_SIGN="${STRICT_SIGN:-false}"

supports_flag() {
  local cmd="$1"
  local flag="$2"
  cosign "$cmd" -h 2>/dev/null | grep -q -- "$flag"
}

if command -v cosign >/dev/null 2>&1; then
  log "Cosign available; generate keypair if missing"
  mkdir -p "${KEY_DIR}"
  if [ ! -f "${KEY_PREFIX}.key" ]; then
    export COSIGN_PASSWORD="${COSIGN_PASSWORD:-localpass}"
    (cd "${KEY_DIR}" && cosign generate-key-pair)
  fi
  export COSIGN_PASSWORD="${COSIGN_PASSWORD:-localpass}"
  export COSIGN_TLOG_UPLOAD="${COSIGN_TLOG_UPLOAD:-false}"
  export COSIGN_ALLOW_INSECURE_REGISTRY="${COSIGN_ALLOW_INSECURE_REGISTRY:-1}"

  sign_args=(sign --key "${KEY_PREFIX}.key")
  if supports_flag sign "--allow-insecure-registry"; then
    sign_args+=(--allow-insecure-registry)
  fi
  sign_args+=("${IMAGE_TAG}")

  set +e
  cosign "${sign_args[@]}"
  sign_status=$?
  if [ "${sign_status}" -ne 0 ] && supports_flag sign "--tlog-upload"; then
    log "Retry sign with --tlog-upload=false"
    cosign "${sign_args[@]}" --tlog-upload=false
    sign_status=$?
  fi
  set -e

  if [ "${sign_status}" -ne 0 ]; then
    log "Sign thất bại"
    if [ "${STRICT_SIGN}" = "true" ]; then
      exit 1
    fi
    echo "sign failed: ${IMAGE_TAG}" > "${SIGN_PATH}"
  else
    verify_args=(verify --key "${KEY_PREFIX}.pub")
    if supports_flag verify "--insecure-ignore-tlog"; then
      verify_args+=(--insecure-ignore-tlog)
    fi
    if supports_flag verify "--allow-insecure-registry"; then
      verify_args+=(--allow-insecure-registry)
    fi
    verify_args+=("${IMAGE_TAG}")

    set +e
    cosign "${verify_args[@]}" > "${RUN_DIR}/data/verify_sign.json"
    verify_status=$?
    set -e
    if [ "${verify_status}" -ne 0 ]; then
      log "Verify signature thất bại, tiếp tục pipeline"
    fi
    echo "signed: ${IMAGE_TAG}" > "${SIGN_PATH}"
  fi
else
  log "Không có cosign; tạo placeholder"
  cat > "${SIGN_PATH}" <<EOF_SIGN
cosign not found; signature skipped for ${IMAGE_TAG}
EOF_SIGN
fi

finalize_stage "${STAGE_NAME}" "success"
