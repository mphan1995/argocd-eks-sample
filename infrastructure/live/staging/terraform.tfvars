environment = "staging"
vpc_cidr    = "10.20.0.0/16"

admin_cidr_blocks                    = ["165.85.191.79/32"]
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["165.85.191.79/32"]

create_ecr          = false
ecr_repository_name = "cloudnative-app"
deploy_jenkins      = false

node_instance_types = ["t3.large"]
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 6
