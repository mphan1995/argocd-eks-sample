#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${1:?Usage: scan.sh <image-ref>}"

trivy image --exit-code 1 --severity HIGH,CRITICAL --no-progress "${IMAGE_REF}"
