variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "eks_oidc_issuer" {
  description = "EKS OIDC issuer URL"
  type        = string
}

variable "jenkins_role_arn" {
  description = "IAM role ARN used by Jenkins EC2"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name for app runtime"
  type        = string
  default     = "app-sa"
}

variable "secrets_prefix" {
  description = "SSM/Secrets Manager prefix for runtime secrets"
  type        = string
  default     = "/cloudnative-app"
}

variable "common_tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
