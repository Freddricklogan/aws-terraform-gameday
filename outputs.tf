output "application_url" {
  description = "Public URL of the application. Open this after apply."
  value       = module.alb.url
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = module.alb.dns_name
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnets hosting the load balancer."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnets hosting the application instances."
  value       = module.network.private_subnet_ids
}

output "availability_zones" {
  description = "Availability zones in use."
  value       = module.network.availability_zones
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group."
  value       = module.compute.autoscaling_group_name
}

output "app_security_group_id" {
  description = "Security group applied to the application instances."
  value       = module.alb.app_security_group_id
}

output "access_logs_bucket" {
  description = "S3 bucket receiving ALB access logs."
  value       = module.observability.access_logs_bucket
}

output "flow_log_group_arn" {
  description = "CloudWatch log group receiving VPC flow logs."
  value       = module.observability.flow_log_group_arn
}

output "alarm_topic_arn" {
  description = "SNS topic the CloudWatch alarms publish to."
  value       = module.observability.alarm_topic_arn
}

output "session_manager_hint" {
  description = "How to open a shell on an instance now that port 22 is closed."
  value       = "aws ssm start-session --target <instance-id>  # instance ids: aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${module.compute.autoscaling_group_name}"
}
