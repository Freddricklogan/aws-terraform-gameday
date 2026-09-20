variable "name_prefix" {
  type        = string
  description = "Prefix applied to log group, bucket and topic names."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-32 chars, lowercase alphanumeric or hyphen, and must not start or end with a hyphen."
  }
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention for VPC flow logs."
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be one of the retention periods CloudWatch Logs accepts (e.g. 30, 90, 365). Never 0 / never-expire."
  }
}

variable "access_log_expiration_days" {
  type        = number
  description = "Days after which ALB access log objects are expired from S3."
  default     = 90

  validation {
    condition     = var.access_log_expiration_days >= 30 && var.access_log_expiration_days <= 3650
    error_message = "access_log_expiration_days must be between 30 and 3650 to satisfy a minimum evidence-retention window."
  }
}

variable "alarm_email" {
  type        = string
  description = "Optional email subscribed to the alarm topic. Empty string creates the topic with no subscription."
  default     = ""

  validation {
    condition     = var.alarm_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[a-zA-Z]{2,}$", var.alarm_email))
    error_message = "alarm_email must be empty or a syntactically valid email address."
  }
}
