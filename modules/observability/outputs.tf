output "access_logs_bucket" {
  description = "Name of the S3 bucket that receives ALB access logs."
  value       = aws_s3_bucket.access_logs.bucket
}

output "access_logs_bucket_arn" {
  description = "ARN of the ALB access log bucket."
  value       = aws_s3_bucket.access_logs.arn
}

output "access_logs_prefix" {
  description = "Key prefix the ALB must write access logs under, matching the bucket policy."
  value       = "alb"
}

output "flow_log_group_arn" {
  description = "ARN of the CloudWatch log group for VPC flow logs."
  value       = aws_cloudwatch_log_group.flow_logs.arn
}

output "flow_log_role_arn" {
  description = "ARN of the IAM role the VPC flow log service assumes."
  value       = aws_iam_role.flow_logs.arn
}

output "alarm_topic_arn" {
  description = "ARN of the SNS topic CloudWatch alarms publish to."
  value       = aws_sns_topic.alarms.arn
}
