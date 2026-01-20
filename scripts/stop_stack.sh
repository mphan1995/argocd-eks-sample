#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infra/docker-compose.yml"

COMPOSE=()
if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "Không tìm thấy docker compose" >&2
  exit 1
fi

ENV_ARGS=()
if [ -f "${ROOT_DIR}/.env" ]; then
  ENV_ARGS=(--env-file "${ROOT_DIR}/.env")
fi

"${COMPOSE[@]}" -f "${COMPOSE_FILE}" "${ENV_ARGS[@]}" down
