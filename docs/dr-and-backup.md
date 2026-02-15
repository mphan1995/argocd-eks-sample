# DR and Backup Strategy

## Terraform State
- State bucket versioning enabled.
- DynamoDB lock table prevents concurrent state corruption.
- `prevent_destroy` on backend resources.

## Container Artifacts
- ECR lifecycle policy retains recent images.
- Use immutable tags and digest-based rollback.
- Keep SBOM artifacts in S3 for forensic and compliance review.

## Kubernetes Workloads
- Store manifests and Helm values in Git (GitOps-compatible history).
- Rollback with Helm:

```bash
helm history cloudnative-app -n prod
helm rollback cloudnative-app <REVISION> -n prod
```

## Regional Resilience (next phase)
- Replicate ECR images cross-region.
- Use secondary region for warm-standby EKS.
- Replicate critical secrets and backup snapshots.
