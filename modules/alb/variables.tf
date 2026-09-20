variable "name_prefix" {
  type        = string
  description = "Prefix applied to the ALB, target group and security group names."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-32 chars, lowercase alphanumeric or hyphen, and must not start or end with a hyphen."
  }

  validation {
    condition     = length(var.name_prefix) <= 26
    error_message = "name_prefix must be 26 chars or fewer: AWS caps load balancer and target group names at 32 and this module appends '-alb' / '-tg'."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC the target group is registered in."

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id must look like vpc-0123456789abcdef0."
  }
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets the internet-facing ALB is attached to."

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "An Application Load Balancer requires subnets in at least two availability zones."
  }
}

variable "ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks permitted to reach the ALB listener. Defaults to the public internet because this is a public web tier."
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.ingress_cidrs) > 0
    error_message = "ingress_cidrs must contain at least one CIDR block."
  }

  validation {
    condition     = alltrue([for c in var.ingress_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in ingress_cidrs must be a valid IPv4 CIDR block."
  }
}

variable "app_port" {
  type        = number
  description = "Port the application listens on inside the private subnets."
  default     = 80

  validation {
    condition     = var.app_port > 0 && var.app_port <= 65535
    error_message = "app_port must be a valid TCP port between 1 and 65535."
  }
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN. When set, the ALB serves HTTPS on 443 and redirects 80 -> 443. When empty, it serves plain HTTP on 80 (training default)."
  default     = ""

  validation {
    condition     = var.certificate_arn == "" || can(regex("^arn:aws[a-z-]*:acm:", var.certificate_arn))
    error_message = "certificate_arn must be empty or a valid ACM certificate ARN."
  }
}

variable "ssl_policy" {
  type        = string
  description = "ELB security policy used for the HTTPS listener."
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  validation {
    condition     = can(regex("TLS13|TLS-1-2", var.ssl_policy))
    error_message = "ssl_policy must be a TLS 1.2 or TLS 1.3 policy; older policies permit deprecated ciphers."
  }
}

variable "access_logs_bucket" {
  type        = string
  description = "S3 bucket that receives ALB access logs."

  validation {
    condition     = length(var.access_logs_bucket) >= 3
    error_message = "access_logs_bucket must be set: ALB access logging is mandatory in this configuration."
  }
}

variable "access_logs_prefix" {
  type        = string
  description = "Key prefix for ALB access logs, must match the bucket policy."
  default     = "alb"
}

variable "health_check_path" {
  type        = string
  description = "HTTP path the target group probes."
  default     = "/"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must start with a forward slash."
  }
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Protect the ALB from accidental deletion. Off by default so Game Day environments can be destroyed."
  default     = false
}

variable "enable_alarms" {
  type        = bool
  description = "Explicitly enable or disable the CloudWatch alarms. Leave null to derive from alarm_topic_arn. The root module sets this so that count depends only on plan-time-known input, never on an apply-time attribute."
  default     = null
}

variable "alarm_topic_arn" {
  type        = string
  description = "SNS topic CloudWatch alarms publish to. Empty string disables alarms."
  default     = ""
}

variable "unhealthy_host_threshold" {
  type        = number
  description = "Number of unhealthy targets that triggers the alarm."
  default     = 1

  validation {
    condition     = var.unhealthy_host_threshold >= 1
    error_message = "unhealthy_host_threshold must be at least 1."
  }
}
