#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:?Usage: deploy.sh <cluster> <namespace> <values-file> [release-name]}"
NAMESPACE="${2:?Usage: deploy.sh <cluster> <namespace> <values-file> [release-name]}"
VALUES_FILE="${3:?Usage: deploy.sh <cluster> <namespace> <values-file> [release-name]}"
RELEASE_NAME="${4:-cloudnative-app}"

: "${AWS_REGION:?AWS_REGION must be set}"
: "${IMAGE_REPO:?IMAGE_REPO must be set}"
: "${IMAGE_DIGEST:?IMAGE_DIGEST must be set}"

aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

helm upgrade --install "${RELEASE_NAME}" ./helm/cloudnative-app \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 10m \
  -f "${VALUES_FILE}" \
  --set image.repository="${IMAGE_REPO}" \
  --set image.digest="${IMAGE_DIGEST}"
