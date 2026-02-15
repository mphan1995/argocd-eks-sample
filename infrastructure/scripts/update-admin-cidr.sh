#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [public_ip]"
  exit 1
fi

if [[ $# -eq 1 ]]; then
  IP="$1"
else
  IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')"
fi

if [[ ! "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Invalid IPv4 address: $IP"
  exit 1
fi

CIDR="${IP}/32"

for tfvars in "$ROOT_DIR/live"/dev/terraform.tfvars "$ROOT_DIR/live"/staging/terraform.tfvars "$ROOT_DIR/live"/prod/terraform.tfvars; do
  sed -i -E "s#^(admin_cidr_blocks[[:space:]]*= ).*#\\1[\"${CIDR}\"]#" "$tfvars"
  sed -i -E "s#^(cluster_endpoint_public_access_cidrs[[:space:]]*= ).*#\\1[\"${CIDR}\"]#" "$tfvars"
  echo "Updated $tfvars"
done

echo "Done. All admin and EKS endpoint CIDRs set to ${CIDR}."
