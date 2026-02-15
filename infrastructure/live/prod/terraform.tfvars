environment = "prod"
vpc_cidr    = "10.30.0.0/16"

admin_cidr_blocks                    = ["165.85.191.79/32"]
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["165.85.191.79/32"]

create_ecr          = false
ecr_repository_name = "cloudnative-app"
deploy_jenkins      = false

node_instance_types = ["m6i.large"]
node_desired_size   = 3
node_min_size       = 3
node_max_size       = 12
