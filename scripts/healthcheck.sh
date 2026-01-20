#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

check_port() {
  local name="$1"
  local host="$2"
  local port="$3"
  if (echo > "/dev/tcp/${host}/${port}") >/dev/null 2>&1; then
    printf "%-10s : OK (:%s)\n" "$name" "$port"
  else
    printf "%-10s : FAIL (:%s)\n" "$name" "$port"
  fi
}

check_port "gitea" "127.0.0.1" 3000
check_port "jenkins" "127.0.0.1" 8080
check_port "registry" "127.0.0.1" 5000
check_port "nexus" "127.0.0.1" 8081
