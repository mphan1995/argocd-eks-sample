locals {
  common_tags = {
    environment = var.environment
    managed_by  = "terraform"
    account_id  = var.account_id
    platform    = "enterprise-cicd"
  }
}

module "vpc" {
  source             = "../../modules/vpc"
  environment        = var.environment
  cidr_block         = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = true
  common_tags        = local.common_tags
}

module "security_groups" {
  source            = "../../modules/security-groups"
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = var.vpc_cidr
  admin_cidr_blocks = var.admin_cidr_blocks
  common_tags       = local.common_tags
}

module "ecr" {
  count       = var.create_ecr ? 1 : 0
  source      = "../../modules/ecr"
  environment = var.environment
  repo_name   = var.ecr_repository_name
  common_tags = local.common_tags
}

module "eks" {
  source                               = "../../modules/eks"
  environment                          = var.environment
  cluster_name                         = "platform-${var.environment}"
  kubernetes_version                   = var.cluster_version
  vpc_id                               = module.vpc.vpc_id
  private_subnet_ids                   = module.vpc.private_subnet_ids
  extra_security_group_ids             = [module.security_groups.eks_control_plane_sg_id]
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_admin_principal_arns         = [
    var.jenkins_role_arn,
    "arn:aws:iam::${var.account_id}:user/devops-admin",
    "arn:aws:iam::${var.account_id}:user/devops-ci-cd"
  ]
  node_instance_types                  = var.node_instance_types
  node_desired_size                    = var.node_desired_size
  node_min_size                        = var.node_min_size
  node_max_size                        = var.node_max_size
  common_tags                          = local.common_tags
}

module "iam" {
  source               = "../../modules/iam"
  environment          = var.environment
  account_id           = var.account_id
  region               = var.region
  eks_oidc_issuer      = module.eks.oidc_issuer_url
  jenkins_role_arn     = var.jenkins_role_arn
  service_account_name = var.service_account_name
  secrets_prefix       = var.secrets_prefix
  common_tags          = local.common_tags
}

module "ec2_jenkins" {
  count                       = var.deploy_jenkins ? 1 : 0
  source                      = "../../modules/ec2-jenkins"
  environment                 = var.environment
  subnet_id                   = module.vpc.public_subnet_ids[0]
  security_group_ids          = [module.security_groups.jenkins_sg_id]
  iam_instance_profile_name   = var.jenkins_instance_profile_name
  instance_type               = var.jenkins_instance_type
  associate_public_ip_address = var.jenkins_associate_public_ip
  common_tags                 = local.common_tags
}
