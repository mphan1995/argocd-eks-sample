variable "account_id" {
  description = "AWS account ID"
  type        = string
  default     = "508591325080"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the environment VPC"
  type        = string
}

variable "az_count" {
  description = "Number of AZs"
  type        = number
  default     = 3
}

variable "admin_cidr_blocks" {
  description = "CIDRs that can access Jenkins and EKS API"
  type        = list(string)
}

variable "create_ecr" {
  description = "Create ECR repository in this environment stack"
  type        = bool
  default     = false
}

variable "ecr_repository_name" {
  description = "Shared ECR repository name"
  type        = string
  default     = "cloudnative-app"
}

variable "jenkins_role_arn" {
  description = "Existing Jenkins EC2 role ARN"
  type        = string
  default     = "arn:aws:iam::508591325080:role/JenkinsEC2Role"
}

variable "jenkins_instance_profile_name" {
  description = "Existing Jenkins EC2 instance profile name"
  type        = string
  default     = "JenkinsEC2InstanceProfile"
}

variable "deploy_jenkins" {
  description = "Whether to deploy Jenkins EC2 in this environment"
  type        = bool
  default     = false
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.large"
}

variable "jenkins_associate_public_ip" {
  description = "Whether Jenkins gets a public IP"
  type        = bool
  default     = false
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_public_access" {
  description = "Whether EKS API endpoint is public"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed for EKS public endpoint"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EKS node group instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 6
}

variable "service_account_name" {
  description = "Service account used by application"
  type        = string
  default     = "app-sa"
}

variable "secrets_prefix" {
  description = "SSM/Secrets Manager path prefix"
  type        = string
  default     = "/cloudnative-app"
}
