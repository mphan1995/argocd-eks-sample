variable "environment" {
  description = "Environment name"
  type        = string
}

variable "repo_name" {
  description = "ECR repository name"
  type        = string
}

variable "scan_on_push" {
  description = "Enable ECR scan on push"
  type        = bool
  default     = true
}

variable "immutable_tags" {
  description = "Whether image tags are immutable"
  type        = bool
  default     = true
}

variable "retain_last_n_images" {
  description = "How many tagged images to keep"
  type        = number
  default     = 50
}

variable "common_tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
