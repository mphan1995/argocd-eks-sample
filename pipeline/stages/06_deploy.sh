#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

STAGE_NAME="06_deploy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../base_stage.sh
source "${PIPELINE_DIR}/base_stage.sh"

init_stage "${STAGE_NAME}"

trap 'finalize_stage "${STAGE_NAME}" "failed"' ERR

require_cmd kind
require_cmd kubectl
require_cmd helm
require_cmd docker

CLUSTER_NAME="${KIND_CLUSTER_NAME:-local-max}"
IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:${TAG}"
CHART_DIR="${WORKSPACE}/app/helm/sample-app"

if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  log "Create kind cluster: ${CLUSTER_NAME}"
  kind create cluster --name "${CLUSTER_NAME}" --config "${WORKSPACE}/infra/kind/kind-cluster.yaml"
else
  log "Kind cluster exists: ${CLUSTER_NAME}"
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

log "Load image into kind"
kind load docker-image "${IMAGE_TAG}" --name "${CLUSTER_NAME}"

log "Deploy Helm chart"
helm upgrade --install sample-app "${CHART_DIR}" \
  --namespace sample-app \
  --create-namespace \
  --set image.repository="${REGISTRY_URL}/${IMAGE_NAME}" \
  --set image.tag="${TAG}" \
  --set service.type=NodePort \
  --set service.nodePort=30080 \
  --wait --timeout 180s

kubectl -n sample-app get pods -o wide > "${RUN_DIR}/data/k8s_pods.txt"

finalize_stage "${STAGE_NAME}" "success"
