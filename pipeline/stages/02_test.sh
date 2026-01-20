#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

STAGE_NAME="02_test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../base_stage.sh
source "${PIPELINE_DIR}/base_stage.sh"

init_stage "${STAGE_NAME}"

trap 'finalize_stage "${STAGE_NAME}" "failed"' ERR

require_cmd python3

APP_DIR="${WORKSPACE}/app/sample-app"

log "Run python bytecode compile"
python3 -m py_compile "${APP_DIR}/app.py"

echo "ok" > "${RUN_DIR}/data/test_status.txt"

finalize_stage "${STAGE_NAME}" "success"
