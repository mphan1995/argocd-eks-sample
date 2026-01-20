#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

missing=()

check_cmd() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd -> $hint")
  fi
}

check_cmd docker "Cài Docker Desktop + bật WSL2 integration"

if command -v docker >/dev/null 2>&1; then
  if ! docker compose version >/dev/null 2>&1; then
    if ! command -v docker-compose >/dev/null 2>&1; then
      missing+=("docker compose -> Cài Docker Desktop hoặc docker-compose plugin")
    fi
  fi
fi

check_cmd git "sudo apt-get install -y git"
check_cmd python3 "sudo apt-get install -y python3"

if command -v python3 >/dev/null 2>&1; then
  if ! python3 - <<'PY'
import venv
PY
  then
    missing+=("python3-venv -> sudo apt-get install -y python3-venv")
  fi
fi

if [ "${#missing[@]}" -ne 0 ]; then
  echo "Thiếu tool:" 
  printf ' - %s\n' "${missing[@]}"
fi

if command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY'
import venv
PY
  then
    if [ ! -d "${ROOT_DIR}/ui/.venv" ]; then
      echo "Tạo venv cho UI"
      python3 -m venv "${ROOT_DIR}/ui/.venv"
    fi
    echo "Cài requirements cho UI"
    "${ROOT_DIR}/ui/.venv/bin/pip" install --upgrade pip
    "${ROOT_DIR}/ui/.venv/bin/pip" install -r "${ROOT_DIR}/ui/requirements.txt"
  else
    echo "Thiếu python3-venv; bỏ qua tạo venv"
  fi
fi

echo "Bootstrap xong. Nếu thiếu tool, hãy cài theo gợi ý ở trên."
