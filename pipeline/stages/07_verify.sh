#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

STAGE_NAME="07_verify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../base_stage.sh
source "${PIPELINE_DIR}/base_stage.sh"

init_stage "${STAGE_NAME}"

trap 'finalize_stage "${STAGE_NAME}" "failed"' ERR

require_cmd kubectl

NAMESPACE="sample-app"
SERVICE_NAME="sample-app"
LOCAL_PORT=18080
RESPONSE_PATH="${RUN_DIR}/data/verify_response.json"
PF_LOG="${RUN_DIR}/data/port_forward.log"

kubectl -n "${NAMESPACE}" rollout status deploy/sample-app --timeout=120s

kubectl -n "${NAMESPACE}" port-forward "svc/${SERVICE_NAME}" "${LOCAL_PORT}:80" > "${PF_LOG}" 2>&1 &
PF_PID=$!

cleanup() {
  kill "${PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 2

URL="http://127.0.0.1:${LOCAL_PORT}/health"
if command -v curl >/dev/null 2>&1; then
  curl -fsS "${URL}" > "${RESPONSE_PATH}"
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "${URL}" > "${RESPONSE_PATH}"
elif command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY' "${URL}" > "${RESPONSE_PATH}"
import sys
import urllib.request
url = sys.argv[1]
print(urllib.request.urlopen(url, timeout=5).read().decode())
PY
else
  log "Không có curl/wget/python3 để verify"
  exit 1
fi

log "Verify OK"
finalize_stage "${STAGE_NAME}" "success"
