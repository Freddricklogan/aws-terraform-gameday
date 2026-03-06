# =============================================================================
# Outputs -- Values displayed after terraform apply completes
# =============================================================================

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = "http://${aws_lb.web.dns_name}"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "IDs of all subnets"
  value       = aws_subnet.public[*].id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.web.id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "availability_zones" {
  description = "Availability zones used"
  value       = data.aws_availability_zones.available.names
}
