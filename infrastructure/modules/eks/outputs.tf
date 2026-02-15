output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  description = "Base64 encoded cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_issuer_url" {
  description = "EKS OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "node_iam_role_arn" {
  description = "Managed node group IAM role ARN"
  value       = module.eks.eks_managed_node_groups["default"].iam_role_arn
}
