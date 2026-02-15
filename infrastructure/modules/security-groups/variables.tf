variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "Target VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR for east-west controls"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to access Jenkins"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "common_tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
