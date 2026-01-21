#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infra/docker-compose.yml"
VOLUME_DIR="${ROOT_DIR}/infra/volumes"
GITEA_SEED="${ROOT_DIR}/scm/gitea/app.ini"

log() {
  printf "[%s] %s\n" "$(date +"%H:%M:%S")" "$*"
}

ensure_dir() {
  mkdir -p "$1"
}

ensure_owner() {
  local path="$1"
  local uid="${2:-1000}"
  local gid="${3:-1000}"
  local current
  current="$(stat -c "%u:%g" "$path" 2>/dev/null || true)"
  if [ "$current" = "${uid}:${gid}" ]; then
    return 0
  fi
  if chown -R "${uid}:${gid}" "$path" >/dev/null 2>&1; then
    log "Đã chỉnh owner ${path} -> ${uid}:${gid}"
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    log "Cần sudo để chỉnh owner ${path}"
    sudo chown -R "${uid}:${gid}" "$path"
    return 0
  fi
  log "Không thể chỉnh owner ${path}. Hãy chạy: sudo chown -R ${uid}:${gid} ${path}"
  exit 1
}

seed_gitea_config() {
  local target="${VOLUME_DIR}/gitea/gitea/conf/app.ini"
  if [ -f "${target}" ]; then
    return 0
  fi
  if [ ! -f "${GITEA_SEED}" ]; then
    return 0
  fi
  ensure_dir "$(dirname "${target}")"
  cp "${GITEA_SEED}" "${target}"
  log "Seed Gitea config -> ${target}"
}

COMPOSE=()
if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "Không tìm thấy docker compose" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon chưa sẵn sàng. Kiểm tra Docker Desktop + WSL integration." >&2
  exit 1
fi

ensure_dir "${VOLUME_DIR}/gitea"
ensure_dir "${VOLUME_DIR}/jenkins"
ensure_dir "${VOLUME_DIR}/registry"
ensure_owner "${VOLUME_DIR}/gitea" 1000 1000
ensure_owner "${VOLUME_DIR}/jenkins" 1000 1000

seed_gitea_config

ENV_ARGS=()
if [ -f "${ROOT_DIR}/.env" ]; then
  ENV_ARGS=(--env-file "${ROOT_DIR}/.env")
fi

PROFILE_ARGS=()
if [ -z "${ENABLE_NEXUS:-}" ] && [ -f "${ROOT_DIR}/.env" ]; then
  ENABLE_NEXUS="$(grep -E '^ENABLE_NEXUS=' "${ROOT_DIR}/.env" | tail -n 1 | cut -d= -f2- || true)"
  ENABLE_NEXUS="${ENABLE_NEXUS%\"}"
  ENABLE_NEXUS="${ENABLE_NEXUS#\"}"
fi
if [ "${ENABLE_NEXUS:-false}" = "true" ]; then
  PROFILE_ARGS+=(--profile nexus)
fi

"${COMPOSE[@]}" -f "${COMPOSE_FILE}" "${ENV_ARGS[@]}" "${PROFILE_ARGS[@]}" up -d
"${COMPOSE[@]}" -f "${COMPOSE_FILE}" "${ENV_ARGS[@]}" "${PROFILE_ARGS[@]}" ps
