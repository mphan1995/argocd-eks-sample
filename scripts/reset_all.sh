#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${CONFIRM:-}" != "YES" ]; then
  echo "CẢNH BÁO: Thao tác này sẽ xóa volumes và output local."
  read -r -p "Nhập YES để tiếp tục: " ans
  if [ "$ans" != "YES" ]; then
    echo "Hủy."
    exit 0
  fi
fi

"${ROOT_DIR}/scripts/stop_stack.sh" || true

rm -rf "${ROOT_DIR}/infra/volumes"/* || true
rm -rf "${ROOT_DIR}/pipeline/output"/* || true

if command -v kind >/dev/null 2>&1; then
  kind delete cluster --name "${KIND_CLUSTER_NAME:-local-max}" || true
fi

echo "Reset xong."
