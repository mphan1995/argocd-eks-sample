output "instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = aws_instance.jenkins.id
}

output "private_ip" {
  description = "Jenkins private IP"
  value       = aws_instance.jenkins.private_ip
}

output "public_ip" {
  description = "Jenkins public IP (if enabled)"
  value       = aws_instance.jenkins.public_ip
}
