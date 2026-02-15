# Deployment Runbook

## 0) AWS Profile and Identity Check

Use `devops-admin` for Terraform bootstrap and infrastructure changes.

```bash
aws configure list-profiles
# If missing:
# aws configure --profile devops-admin

aws sts get-caller-identity --profile devops-admin
export AWS_PROFILE=devops-admin
```

Expected ARN pattern:
- `arn:aws:iam::508591325080:user/devops-admin`

Do not run Terraform with root credentials or `devops-ci-cd` for bootstrap.

## 1) Bootstrap Terraform Backend (one-time)

```bash
cd infrastructure/bootstrap/backend
terraform init
terraform validate
terraform plan -out=bootstrap.tfplan \
  -var="bucket_name=tfstate-508591325080-us-east-1" \
  -var="dynamodb_table_name=tf-locks" \
  -var="region=us-east-1"
terraform show -no-color bootstrap.tfplan
terraform apply bootstrap.tfplan
```

## 2) Deploy Environment Infrastructure

### Dev
```bash
cd infrastructure/live/dev
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars -out=dev.tfplan
terraform show -no-color dev.tfplan
terraform apply dev.tfplan
```

### Staging
```bash
cd infrastructure/live/staging
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars -out=staging.tfplan
terraform show -no-color staging.tfplan
terraform apply staging.tfplan
```

### Prod
```bash
cd infrastructure/live/prod
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars -out=prod.tfplan
terraform show -no-color prod.tfplan
terraform apply prod.tfplan
```

## 3) Jenkins Setup
- Install required Jenkins tools/plugins on the EC2 host:
  - Docker CLI
  - AWS CLI v2
  - Helm
  - kubectl
  - Trivy
  - Syft
- Configure pipeline job using `jenkins/Jenkinsfile`.

## 4) Pipeline Behavior
1. Checkout source code.
2. Build and unit test app.
3. Build Docker image tagged by commit SHA.
4. Run Trivy scan.
5. Generate SBOM and archive artifact.
6. Push image to ECR.
7. Deploy to `dev` namespace on EKS.
8. Manual approval gate.
9. Promote same image digest to `staging` and then `prod`.

## 5) Post-deploy Verification
```bash
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n prod
kubectl rollout status deployment/cloudnative-app -n prod
```

## 6) Operator IP Allowlist Note
- `admin_cidr_blocks` and `cluster_endpoint_public_access_cidrs` must use your public egress IP (for example from `curl https://checkip.amazonaws.com`).
- Do not use WSL/Linux private interface IPs such as `172.19.x.x` for internet-exposed SG/EKS endpoint allowlists.
- Quick update command (all environments):

```bash
bash infrastructure/scripts/update-admin-cidr.sh
```

## 7) Safer Terraform Command Wrapper

Use the helper script to enforce `plan` before `apply`:

```bash
bash infrastructure/scripts/tf-plan-apply.sh dev --profile devops-admin
bash infrastructure/scripts/tf-plan-apply.sh dev --profile devops-admin --apply
```

## 8) Troubleshooting Partial Apply (EKS Access Entry Conflict)

If `apply` fails with:
- `ResourceInUseException: The specified access entry resource is already in use`

run import to reconcile Terraform state with existing EKS access entries:

```bash
cd infrastructure/live/dev
export AWS_PROFILE=devops-admin

terraform import 'module.eks.module.eks.aws_eks_access_entry.this["admin_0"]' 'platform-dev:arn:aws:iam::508591325080:role/JenkinsEC2Role'
terraform import 'module.eks.module.eks.aws_eks_access_entry.this["admin_1"]' 'platform-dev:arn:aws:iam::508591325080:user/devops-admin'
terraform import 'module.eks.module.eks.aws_eks_access_entry.this["admin_2"]' 'platform-dev:arn:aws:iam::508591325080:user/devops-ci-cd'
```

Then rerun:

```bash
bash infrastructure/scripts/tf-plan-apply.sh dev --profile devops-admin
bash infrastructure/scripts/tf-plan-apply.sh dev --profile devops-admin --apply
```

## 9) Troubleshooting State Persist Failure (S3 Backend)

If apply ends with:
- `Failed to save state`
- `Failed to persist state to backend`
- message about local `errored.tfstate`

recover in this order (do not run a new `apply` first):

```bash
cd infrastructure/live/dev
export AWS_PROFILE=devops-admin

cp errored.tfstate errored.tfstate.backup
terraform state push errored.tfstate
terraform plan -var-file=terraform.tfvars -out=dev.tfplan
```

If `terraform state push` fails with auth/session errors, refresh credentials then retry:

```bash
aws sso login --profile devops-admin
terraform state push errored.tfstate
```
