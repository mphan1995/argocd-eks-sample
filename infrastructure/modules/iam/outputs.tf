output "cicd_deploy_role_arn" {
  description = "IAM role ARN assumed by Jenkins for deployments"
  value       = aws_iam_role.cicd_deploy_role.arn
}

output "cicd_deploy_role_name" {
  description = "IAM role name assumed by Jenkins for deployments"
  value       = aws_iam_role.cicd_deploy_role.name
}

output "app_irsa_role_arn" {
  description = "IAM role ARN for application service account"
  value       = aws_iam_role.app_irsa_role.arn
}

output "app_irsa_role_name" {
  description = "IAM role name for application service account"
  value       = aws_iam_role.app_irsa_role.name
}
