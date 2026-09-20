output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB tier)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (application tier)."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability zones the tiers are spread across."
  value       = local.azs
}

output "flow_logs_enabled" {
  description = "Whether VPC flow logs were created."
  value       = local.enable_flow_logs
}
