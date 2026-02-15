# Security Controls

## IAM and Access Control
- Root account is excluded from daily operations.
- Jenkins uses EC2 instance profile (`JenkinsEC2Role`) instead of static credentials.
- CI deploy role (`CICDDeployRole-<env>`) is assumable only by approved principals.
- Runtime permissions use IRSA role (`AppRuntimeRole-<env>`) bound to namespace/service account.
- `iam:PassRole` should be scoped to explicit role ARNs only.

## Software Supply Chain
- Docker image built via multi-stage Dockerfile.
- Trivy scan blocks build on `HIGH` and `CRITICAL` findings.
- SBOM generated with Syft and archived for traceability.
- ECR repository enforces immutable tags and scan on push.

## Secrets and Configuration
- Secrets are sourced from AWS SSM Parameter Store / Secrets Manager.
- No hardcoded secrets in Terraform, Helm values, or Jenkinsfile.
- Use namespace/env path segmentation, for example:
  - `/cloudnative-app/dev/*`
  - `/cloudnative-app/staging/*`
  - `/cloudnative-app/prod/*`

## Logging and Governance
- Enable EKS control plane logs to CloudWatch.
- Enable CloudTrail for account-level API auditing.
- Budget alerts per environment at 50/80/100 percent actual + forecast.
- GuardDuty recommended for threat detection (optional advanced baseline).

## Hardening Recommendations
- Restrict Jenkins ingress to corporate CIDR or VPN only.
- Use private subnets for worker nodes and least egress paths.
- Add WAF in front of public ALB endpoints for production workloads.
- Enforce branch protection and signed commits for release branches.
