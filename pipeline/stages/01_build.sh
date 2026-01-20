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

if command -v curl >/dev/null 2>&1; then
  if ! curl -fsS "http://${REGISTRY_URL}/v2/" >/dev/null 2>&1; then
    log "Registry chưa sẵn sàng tại ${REGISTRY_URL}"
  fi
fi

log "Build image: ${IMAGE_TAG}"
docker build \
  --pull \
  --label "org.cicd.run_id=${RUN_ID}" \
  --label "org.cicd.stage=build" \
  --label "org.cicd.created_at=$(date -Iseconds)" \
  -t "${IMAGE_TAG}" "${APP_DIR}"

log "Push image: ${IMAGE_TAG}"
docker push "${IMAGE_TAG}"

echo "${IMAGE_TAG}" > "${RUN_DIR}/data/image.txt"
if docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE_TAG}" >/dev/null 2>&1; then
  docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE_TAG}" > "${RUN_DIR}/data/image_digest.txt"
fi

finalize_stage "${STAGE_NAME}" "success"
