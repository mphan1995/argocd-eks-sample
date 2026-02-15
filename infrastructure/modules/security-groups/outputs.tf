output "jenkins_sg_id" {
  description = "Security group ID for Jenkins EC2"
  value       = aws_security_group.jenkins.id
}

output "eks_control_plane_sg_id" {
  description = "Security group ID for EKS control plane"
  value       = aws_security_group.eks_control_plane.id
}

output "alb_sg_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}
