variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for VPC"
  type        = string
}

variable "az_count" {
  description = "Number of AZs to use"
  type        = number
  default     = 3
}

variable "enable_nat_gateway" {
  description = "Whether to create one shared NAT gateway"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
