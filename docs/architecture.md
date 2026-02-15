# Enterprise CI/CD Architecture Blueprint

## Scope
- AWS Account: `508591325080`
- Region: `us-east-1`
- IAM operators: `devops-admin`, `devops-ci-cd`, `auditor`
- Root account: break-glass only

## High-level Architecture

```text
                               +-------------------------------+
                               |   Developers / Git Provider   |
                               +---------------+---------------+
                                               |
                                               | Webhook
                                               v
+-------------------------+        +-----------+------------+
| Terraform (IaC)         |        | Jenkins on EC2         |
| live/dev|staging|prod   |        | IAM Instance Profile   |
+-----------+-------------+        +-----------+------------+
            |                                   |
            | creates                           | Build/Test/Scan/SBOM/Push
            v                                   v
+-----------+-------------+        +-----------+------------+
| VPC, SG, EKS, IAM, ECR  |<-------+ ECR (immutable tags)   |
| per environment         |        +-----------+------------+
+-----------+-------------+                    |
            |                                  | deploy by image digest
            v                                  v
+-----------+----------------------------------+------------+
| EKS Cluster(s)                                              |
| namespaces: dev, staging, prod                              |
| Helm release per namespace                                  |
| IRSA roles per namespace (least privilege runtime access)   |
+-----------+----------------------------------+------------+
            |
            v
+-----------+-------------+
| CloudWatch + CloudTrail |
| Budget Alerts           |
| GuardDuty (optional)    |
+-------------------------+
```

## Design Principles
- Build once, deploy many using immutable image digest.
- Least privilege IAM for CI deploy role and runtime IRSA role.
- No static access keys on EC2 Jenkins or Kubernetes pods.
- Immutable infrastructure through Terraform modules and environment isolation.
- Observability and governance as first-class controls.

## Deployment Strategy
- Helm deployment strategy defaults to `RollingUpdate` for zero-downtime rollouts.
- Promotion flow: `dev -> staging -> prod` behind manual approval gate.
- Same image digest promoted across environments to prevent drift.
