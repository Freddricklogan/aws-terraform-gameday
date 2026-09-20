output "dns_name" {
  description = "Public DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "url" {
  description = "Scheme-correct URL for the load balancer."
  value       = "${local.https_enabled ? "https" : "http"}://${aws_lb.this.dns_name}"
}

output "zone_id" {
  description = "Route 53 hosted zone ID of the load balancer, for alias records."
  value       = aws_lb.this.zone_id
}

output "arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "target_group_arn" {
  description = "ARN of the target group the Auto Scaling group registers with."
  value       = aws_lb_target_group.this.arn
}

output "alb_security_group_id" {
  description = "Security group attached to the load balancer."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group the application instances must use."
  value       = aws_security_group.app.id
}

output "listener_port" {
  description = "Port clients connect to."
  value       = local.listener_port
}

output "https_enabled" {
  description = "Whether the ALB terminates TLS."
  value       = local.https_enabled
}
