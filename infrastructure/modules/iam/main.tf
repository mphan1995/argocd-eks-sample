locals {
  oidc_provider_hostpath = replace(var.eks_oidc_issuer, "https://", "")
  tags = merge(var.common_tags, {
    environment = var.environment
    module      = "iam"
  })
}

data "aws_iam_policy_document" "cicd_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "AWS"
      identifiers = [
        var.jenkins_role_arn,
        "arn:aws:iam::${var.account_id}:user/devops-admin",
        "arn:aws:iam::${var.account_id}:user/devops-ci-cd"
      ]
    }
  }
}

resource "aws_iam_role" "cicd_deploy_role" {
  name               = "CICDDeployRole-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.cicd_assume.json
  max_session_duration = 3600

  tags = merge(local.tags, {
    Name = "CICDDeployRole-${var.environment}"
  })
}

data "aws_iam_policy_document" "cicd_deploy" {
  statement {
    sid    = "EKSDescribe"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRRead"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadParametersAndSecrets"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account_id}:parameter${var.secrets_prefix}/${var.environment}/*",
      "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:*${var.environment}*"
    ]
  }

  statement {
    sid    = "CloudWatchLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cicd_deploy" {
  name   = "CICDDeployPolicy-${var.environment}"
  policy = data.aws_iam_policy_document.cicd_deploy.json
}

resource "aws_iam_role_policy_attachment" "cicd_deploy" {
  role       = aws_iam_role.cicd_deploy_role.name
  policy_arn = aws_iam_policy.cicd_deploy.arn
}

data "aws_iam_policy_document" "irsa_assume" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${var.account_id}:oidc-provider/${local.oidc_provider_hostpath}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:sub"
      values   = ["system:serviceaccount:${var.environment}:${var.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "app_irsa_role" {
  name               = "AppRuntimeRole-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume.json

  tags = merge(local.tags, {
    Name = "AppRuntimeRole-${var.environment}"
  })
}

data "aws_iam_policy_document" "app_runtime" {
  statement {
    sid    = "ReadAppSecrets"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account_id}:parameter${var.secrets_prefix}/${var.environment}/*",
      "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:*${var.environment}*"
    ]
  }

  statement {
    sid    = "CloudWatchApplicationLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "app_runtime" {
  name   = "AppRuntimePolicy-${var.environment}"
  policy = data.aws_iam_policy_document.app_runtime.json
}

resource "aws_iam_role_policy_attachment" "app_runtime" {
  role       = aws_iam_role.app_irsa_role.name
  policy_arn = aws_iam_policy.app_runtime.arn
}
