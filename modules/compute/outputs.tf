output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group."
  value       = aws_autoscaling_group.this.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling group."
  value       = aws_autoscaling_group.this.arn
}

output "launch_template_id" {
  description = "ID of the launch template."
  value       = aws_launch_template.this.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template."
  value       = aws_launch_template.this.latest_version
}

output "instance_role_arn" {
  description = "ARN of the IAM role attached to the instances."
  value       = aws_iam_role.instance.arn
}

output "ami_id" {
  description = "AMI the launch template resolves to."
  value       = data.aws_ssm_parameter.ubuntu_ami.value
  sensitive   = true
}
