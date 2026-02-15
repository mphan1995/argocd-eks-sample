terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      environment = var.environment
      managed_by  = "terraform"
      platform    = "enterprise-cicd"
      account_id  = var.account_id
    }
  }
}
