variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where Jenkins EC2 is deployed"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups attached to Jenkins EC2"
  type        = list(string)
}

variable "iam_instance_profile_name" {
  description = "Existing IAM instance profile name for Jenkins"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.large"
}

variable "ami_id" {
  description = "Optional AMI override"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Optional EC2 key pair name"
  type        = string
  default     = ""
}

variable "associate_public_ip_address" {
  description = "Whether Jenkins should have public IP"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root volume size in GiB"
  type        = number
  default     = 100
}

variable "common_tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
