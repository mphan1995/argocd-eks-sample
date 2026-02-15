# AWS Enterprise CI/CD Skeleton

Production-grade CI/CD skeleton for cloud-native workloads on AWS.

## What this repository contains
- `infrastructure/`: Terraform bootstrap, modules, and live environments.
- `application/`: Sample production-ready application with tests and Dockerfile.
- `helm/`: Helm chart for multi-environment Kubernetes deployment.
- `jenkins/`: Jenkins pipeline and helper scripts.
- `docs/`: Architecture, security controls, runbook, and DR notes.

## Quickstart

1. Bootstrap backend state resources:
```bash
export AWS_PROFILE=devops-admin
aws sts get-caller-identity --query Arn --output text
cd infrastructure/bootstrap/backend
terraform init
terraform validate
terraform plan -out=bootstrap.tfplan \
  -var="bucket_name=tfstate-508591325080-us-east-1" \
  -var="dynamodb_table_name=tf-locks"
terraform show -no-color bootstrap.tfplan
terraform apply bootstrap.tfplan
```

2. Deploy development infrastructure:
```bash
cd infrastructure/live/dev
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars -out=dev.tfplan
terraform show -no-color dev.tfplan
terraform apply dev.tfplan
```

3. Run application locally:
```bash
cd application
npm install
npm run test
npm run build
npm start
```

4. Run Jenkins pipeline from `jenkins/Jenkinsfile`.

## Notes
- Update `admin_cidr_blocks` in each `terraform.tfvars` before applying.
- Use `devops-admin` for Terraform provisioning. `devops-ci-cd` is for CI/CD runtime flows.
- Ensure local AWS profile exists: `aws configure --profile devops-admin`.
- Ensure Jenkins EC2 role/profile already exist: `JenkinsEC2Role`, `JenkinsEC2InstanceProfile`.
- Root account is not used for operations.
