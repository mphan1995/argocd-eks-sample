output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "Environment VPC ID"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "Private subnets"
}

output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "eks_oidc_issuer" {
  value       = module.eks.oidc_issuer_url
  description = "OIDC issuer URL"
}

output "cicd_deploy_role_arn" {
  value       = module.iam.cicd_deploy_role_arn
  description = "Role Jenkins assumes for deployments"
}

output "app_irsa_role_arn" {
  value       = module.iam.app_irsa_role_arn
  description = "Role for app service account"
}

output "ecr_repository_url" {
  value       = var.create_ecr ? module.ecr[0].repository_url : "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repository_name}"
  description = "Container repository URL"
}

output "jenkins_instance_id" {
  value       = try(module.ec2_jenkins[0].instance_id, null)
  description = "Jenkins EC2 ID when deployed"
}

output "jenkins_public_ip" {
  value       = try(module.ec2_jenkins[0].public_ip, null)
  description = "Jenkins public IP when enabled"
}
