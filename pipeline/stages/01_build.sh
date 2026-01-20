#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

STAGE_NAME="01_build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../base_stage.sh
source "${PIPELINE_DIR}/base_stage.sh"

init_stage "${STAGE_NAME}"

trap 'finalize_stage "${STAGE_NAME}" "failed"' ERR

require_cmd docker

docker info >/dev/null 2>&1

APP_DIR="${WORKSPACE}/app/sample-app"
IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:${TAG}"

log "Build image: ${IMAGE_TAG}"
docker build -t "${IMAGE_TAG}" "${APP_DIR}"

log "Push image: ${IMAGE_TAG}"
docker push "${IMAGE_TAG}"

echo "${IMAGE_TAG}" > "${RUN_DIR}/data/image.txt"

finalize_stage "${STAGE_NAME}" "success"
