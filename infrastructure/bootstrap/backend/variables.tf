variable "region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name used for Terraform remote state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name used for Terraform state locking"
  type        = string
}

variable "tags" {
  description = "Common tags applied to backend resources"
  type        = map(string)
  default = {
    platform   = "enterprise-cicd"
    managed_by = "terraform"
  }
}
