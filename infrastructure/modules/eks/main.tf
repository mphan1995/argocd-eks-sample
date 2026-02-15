locals {
  access_entries = {
    for idx, principal_arn in var.cluster_admin_principal_arns :
    "admin_${idx}" => {
      principal_arn = principal_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  cluster_additional_security_group_ids = var.extra_security_group_ids

  # Avoid duplicate access-entry creation when the cluster creator principal
  # already has an existing entry (common in retry/partially-applied clusters).
  enable_cluster_creator_admin_permissions = false
  enable_irsa = true
  access_entries = local.access_entries

  create_cloudwatch_log_group = true
  cluster_enabled_log_types   = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  eks_managed_node_groups = {
    default = {
      name           = "${var.environment}-node-group"
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      ami_type  = "AL2023_x86_64_STANDARD"
      disk_size = 50

      tags = {
        workload = "general"
      }
    }
  }

  tags = merge(var.common_tags, {
    environment = var.environment
    module      = "eks"
  })
}
