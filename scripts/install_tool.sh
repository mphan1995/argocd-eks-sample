#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

TOOL_ID="${1:-}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

if [ -z "${TOOL_ID}" ]; then
  echo "Usage: install_tool.sh <tool_id>" >&2
  exit 2
fi

if [[ "${INSTALL_DIR}" == "~/"* ]]; then
  INSTALL_DIR="${HOME}/${INSTALL_DIR#~/}"
fi

log() {
  printf "[%s] %s\n" "$(date +"%H:%M:%S")" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Thiếu tool: $1"
    return 1
  fi
}

is_venv() {
  python3 - <<'PY'
import sys
raise SystemExit(0 if sys.prefix != sys.base_prefix else 1)
PY
}

ensure_install_dir() {
  mkdir -p "${INSTALL_DIR}"
  if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    log "Gợi ý: thêm ${INSTALL_DIR} vào PATH"
  fi
}

download() {
  local url="$1"
  local dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    log "Cần curl hoặc wget để tải"
    exit 12
  fi
}

install_pytest() {
  if ! command -v python3 >/dev/null 2>&1; then
    log "Thiếu python3"
    exit 11
  fi
  if ! command -v pip3 >/dev/null 2>&1; then
    log "Thiếu pip3. Hãy cài: sudo apt-get install -y python3-pip"
    exit 10
  fi
  if is_venv; then
    log "Đang chạy trong venv; cài pytest vào venv hiện tại"
    python3 -m pip install pytest
  else
    python3 -m pip install --user pytest
  fi
}

install_kind() {
  ensure_install_dir
  download "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64" "${INSTALL_DIR}/kind"
  chmod +x "${INSTALL_DIR}/kind"
}

install_kubectl() {
  ensure_install_dir
  require_cmd curl
  local version
  version="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  download "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl" "${INSTALL_DIR}/kubectl"
  chmod +x "${INSTALL_DIR}/kubectl"
}

install_helm() {
  ensure_install_dir
  require_cmd curl
  HELM_INSTALL_DIR="${INSTALL_DIR}" curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_syft() {
  ensure_install_dir
  require_cmd curl
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b "${INSTALL_DIR}"
}

install_trivy() {
  ensure_install_dir
  require_cmd curl
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "${INSTALL_DIR}"
}

install_cosign() {
  ensure_install_dir
  download "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64" "${INSTALL_DIR}/cosign"
  chmod +x "${INSTALL_DIR}/cosign"
}

install_ort_demo() {
  ensure_install_dir
  cat > "${INSTALL_DIR}/ort" <<'EOF_ORT'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" || "${1:-}" == "version" ]]; then
  echo "ort demo 0.1"
  exit 0
fi
echo "ORT demo stub (không phải bản chính thức)."
exit 0
EOF_ORT
  chmod +x "${INSTALL_DIR}/ort"
}

case "${TOOL_ID}" in
  pytest)
    install_pytest
    ;;
  kind)
    install_kind
    ;;
  kubectl)
    install_kubectl
    ;;
  helm)
    install_helm
    ;;
  syft)
    install_syft
    ;;
  trivy)
    install_trivy
    ;;
  cosign)
    install_cosign
    ;;
  ort)
    install_ort_demo
    ;;
  *)
    log "Tool không hỗ trợ cài tự động: ${TOOL_ID}"
    exit 2
    ;;
 esac

log "Hoàn tất cài ${TOOL_ID}"
