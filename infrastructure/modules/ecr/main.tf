locals {
  tags = merge(var.common_tags, {
    environment = var.environment
    module      = "ecr"
  })
}

resource "aws_ecr_repository" "app" {
  name                 = var.repo_name
  image_tag_mutability = var.immutable_tags ? "IMMUTABLE" : "MUTABLE"

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.tags, {
    Name = var.repo_name
  })
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire images over retention threshold"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.retain_last_n_images
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
