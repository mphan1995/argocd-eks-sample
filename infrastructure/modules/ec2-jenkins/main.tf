data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  selected_ami = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.al2023.value
  tags = merge(var.common_tags, {
    environment = var.environment
    module      = "ec2-jenkins"
  })
}

resource "aws_instance" "jenkins" {
  ami                         = local.selected_ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.iam_instance_profile_name
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = var.key_name != "" ? var.key_name : null

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {})

  tags = merge(local.tags, {
    Name = "jenkins-${var.environment}"
  })
}
