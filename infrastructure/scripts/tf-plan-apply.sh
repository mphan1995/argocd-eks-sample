#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 <environment> [--profile <aws_profile>] [--apply]

Examples:
  $0 dev --profile devops-admin
  $0 prod --profile devops-admin --apply

Behavior:
  - Always runs: init, validate, plan, show
  - Apply runs only when --apply is provided and applies the generated plan file
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

ENV_NAME="$1"
shift

case "$ENV_NAME" in
  dev|staging|prod) ;;
  *)
    echo "Invalid environment: $ENV_NAME"
    usage
    exit 1
    ;;
esac

AWS_PROFILE_NAME="devops-admin"
DO_APPLY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --profile"
        exit 1
      fi
      AWS_PROFILE_NAME="$2"
      shift 2
      ;;
    --apply)
      DO_APPLY="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="$ROOT_DIR/live/$ENV_NAME"
PLAN_FILE="$ENV_DIR/${ENV_NAME}.tfplan"

if [[ ! -d "$ENV_DIR" ]]; then
  echo "Environment directory not found: $ENV_DIR"
  exit 1
fi

export AWS_PROFILE="$AWS_PROFILE_NAME"

echo "[1/5] Verifying AWS identity with profile: $AWS_PROFILE"
aws sts get-caller-identity --query Arn --output text

echo "[2/5] Terraform init ($ENV_NAME)"
terraform -chdir="$ENV_DIR" init -backend-config=backend.hcl

echo "[3/5] Terraform validate ($ENV_NAME)"
terraform -chdir="$ENV_DIR" validate

echo "[4/5] Terraform plan -> $PLAN_FILE"
terraform -chdir="$ENV_DIR" plan -var-file=terraform.tfvars -out="${ENV_NAME}.tfplan"

echo "[5/5] Terraform show plan"
terraform -chdir="$ENV_DIR" show -no-color "${ENV_NAME}.tfplan"

if [[ "$DO_APPLY" == "true" ]]; then
  echo "Applying plan file: $PLAN_FILE"
  if terraform -chdir="$ENV_DIR" apply "${ENV_NAME}.tfplan"; then
    echo "Apply completed successfully."
  else
    ERRORED_STATE_PATH="$ENV_DIR/errored.tfstate"
    if [[ -f "$ERRORED_STATE_PATH" ]]; then
      echo
      echo "Terraform failed to persist state to backend but wrote local recovery state:"
      echo "  $ERRORED_STATE_PATH"
      echo
      echo "Recover safely before any new plan/apply to avoid forked state:"
      echo "  cd $ENV_DIR"
      echo "  cp errored.tfstate errored.tfstate.backup"
      echo "  terraform state push errored.tfstate"
      echo "  terraform plan -var-file=terraform.tfvars -out=${ENV_NAME}.tfplan"
    fi
    exit 1
  fi
else
  echo "Plan complete. Review output above."
  echo "Apply explicitly when ready:"
  echo "  $0 $ENV_NAME --profile $AWS_PROFILE_NAME --apply"
fi
