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
RESPONSE_PATH="${RUN_DIR}/data/verify_response.json"
PF_LOG="${RUN_DIR}/data/port_forward.log"
STATUS_PATH="${RUN_DIR}/data/verify_status.json"

http_get() {
  local url="$1"
  local status=0
  if command -v curl >/dev/null 2>&1; then
    status=$(curl -s -o "${RESPONSE_PATH}" -w "%{http_code}" "${url}" || true)
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${RESPONSE_PATH}" "${url}" && status=200 || status=0
  elif command -v python3 >/dev/null 2>&1; then
    status=$(python3 - <<'PY' "${url}" "${RESPONSE_PATH}")
import sys
import urllib.request
url = sys.argv[1]
dest = sys.argv[2]
try:
    resp = urllib.request.urlopen(url, timeout=5)
    with open(dest, "w", encoding="utf-8") as fh:
        fh.write(resp.read().decode())
    print(resp.status)
except Exception:
    print(0)
PY
  else
    log "Không có curl/wget/python3 để verify"
    return 1
  fi
  printf "%s" "${status}"
}

kubectl -n "${NAMESPACE}" rollout status deploy/sample-app --timeout=120s

NODE_PORT="$(kubectl -n "${NAMESPACE}" get svc "${SERVICE_NAME}" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"
if [ -n "${NODE_PORT}" ]; then
  URL="http://127.0.0.1:${NODE_PORT}/health"
  log "Verify via NodePort ${NODE_PORT}"
  STATUS="$(http_get "${URL}" || true)"
else
  STATUS=0
fi

if [ "${STATUS}" != "200" ]; then
  log "Fallback port-forward"
  LOCAL_PORT=18080
  kubectl -n "${NAMESPACE}" port-forward "svc/${SERVICE_NAME}" "${LOCAL_PORT}:80" > "${PF_LOG}" 2>&1 &
  PF_PID=$!

  cleanup() {
    kill "${PF_PID}" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  sleep 2

  URL="http://127.0.0.1:${LOCAL_PORT}/health"
  STATUS="$(http_get "${URL}" || true)"
fi

cat > "${STATUS_PATH}" <<EOF_STATUS
{
  "url": "${URL}",
  "status": "${STATUS}",
  "checked_at": "$(date -Iseconds)"
}
EOF_STATUS

if [ "${STATUS}" != "200" ]; then
  log "Verify thất bại (HTTP ${STATUS})"
  exit 1
fi

log "Verify OK"
finalize_stage "${STAGE_NAME}" "success"
