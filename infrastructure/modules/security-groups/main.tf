locals {
  tags = merge(var.common_tags, {
    environment = var.environment
    module      = "security-groups"
  })
}

resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg-${var.environment}"
  description = "Jenkins EC2 access controls"
  vpc_id      = var.vpc_id

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "SSH admin access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "jenkins-sg-${var.environment}"
  })
}

resource "aws_security_group" "eks_control_plane" {
  name        = "eks-control-plane-sg-${var.environment}"
  description = "Additional security group for EKS control plane"
  vpc_id      = var.vpc_id

  ingress {
    description = "Kubernetes API from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "eks-control-plane-sg-${var.environment}"
  })
}

resource "aws_security_group" "alb" {
  name        = "alb-sg-${var.environment}"
  description = "ALB ingress security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "alb-sg-${var.environment}"
  })
}
