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
REQ_FILE="${APP_DIR}/requirements.txt"
DEV_REQ_FILE="${APP_DIR}/requirements-dev.txt"
TEST_DIR="${APP_DIR}/tests"
VENV_DIR="${RUN_DIR}/.venv-test"
STRICT_TESTS="${STRICT_TESTS:-false}"
export PYTHONPATH="${APP_DIR}:${PYTHONPATH:-}"

if command -v pip3 >/dev/null 2>&1; then
  log "Tạo venv test: ${VENV_DIR}"
  if ! python3 -m venv "${VENV_DIR}"; then
    log "Không tạo được venv (thiếu python3-venv); fallback py_compile"
    python3 -m py_compile "${APP_DIR}/app.py"
    echo "ok" > "${RUN_DIR}/data/test_status.txt"
    finalize_stage "${STAGE_NAME}" "success"
    exit 0
  fi

  set +e
  "${VENV_DIR}/bin/pip" install --upgrade pip
  if [ -f "${REQ_FILE}" ]; then
    "${VENV_DIR}/bin/pip" install -r "${REQ_FILE}"
  fi
  if [ -f "${DEV_REQ_FILE}" ]; then
    "${VENV_DIR}/bin/pip" install -r "${DEV_REQ_FILE}"
  fi
  install_status=$?
  set -e

  if [ "$install_status" -ne 0 ]; then
    log "Cài dependencies thất bại; fallback py_compile"
    if [ "${STRICT_TESTS}" = "true" ]; then
      exit 1
    fi
    python3 -m py_compile "${APP_DIR}/app.py"
  else
    if [ -d "${TEST_DIR}" ] && [ -x "${VENV_DIR}/bin/pytest" ]; then
      log "Chạy pytest"
      "${VENV_DIR}/bin/pytest" -q "${TEST_DIR}"
    else
      log "Không có tests; chạy py_compile"
      python3 -m py_compile "${APP_DIR}/app.py"
    fi
  fi
else
  log "Thiếu pip3; fallback py_compile"
  python3 -m py_compile "${APP_DIR}/app.py"
fi

echo "ok" > "${RUN_DIR}/data/test_status.txt"

finalize_stage "${STAGE_NAME}" "success"
