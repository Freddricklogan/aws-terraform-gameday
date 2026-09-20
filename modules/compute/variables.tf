variable "name_prefix" {
  type        = string
  description = "Prefix applied to the launch template, ASG and IAM role names."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-32 chars, lowercase alphanumeric or hyphen, and must not start or end with a hyphen."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets the Auto Scaling group launches instances into."

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Provide at least two private subnets so the ASG can survive an AZ failure."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups attached to every instance. Must include the application SG from the alb module."

  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "At least one security group must be attached, otherwise instances land in the VPC default SG."
  }
}

variable "target_group_arn" {
  type        = string
  description = "Target group the ASG registers instances with. This is the attachment that prevents the classic 503."

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:elasticloadbalancing:", var.target_group_arn))
    error_message = "target_group_arn must be a valid elasticloadbalancing ARN."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must look like a valid EC2 instance type, e.g. t3.micro."
  }
}

variable "app_port" {
  type        = number
  description = "Port nginx listens on."
  default     = 80

  validation {
    condition     = var.app_port > 0 && var.app_port <= 65535
    error_message = "app_port must be a valid TCP port between 1 and 65535."
  }
}

variable "min_size" {
  type        = number
  description = "Minimum instance count."
  default     = 2

  validation {
    condition     = var.min_size >= 1
    error_message = "min_size must be at least 1."
  }
}

variable "max_size" {
  type        = number
  description = "Maximum instance count. Acts as the blast-radius and cost ceiling."
  default     = 5

  validation {
    condition     = var.max_size >= 1 && var.max_size <= 20
    error_message = "max_size must be between 1 and 20; higher values are a cost incident waiting to happen in a training account."
  }
}

variable "desired_capacity" {
  type        = number
  description = "Target instance count at steady state."
  default     = 3

  validation {
    condition     = var.desired_capacity >= 1
    error_message = "desired_capacity must be at least 1."
  }

  # Cross-variable validation, available from Terraform 1.9. Before 1.9 this
  # mistake only surfaced as an API error minutes into the apply.
  validation {
    condition     = var.desired_capacity >= var.min_size && var.desired_capacity <= var.max_size
    error_message = "desired_capacity must fall between min_size and max_size."
  }
}

variable "root_volume_size" {
  type        = number
  description = "Size of the encrypted root EBS volume in GiB."
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "root_volume_size must be between 8 and 100 GiB."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "Customer-managed KMS key for EBS encryption. Empty string uses the AWS-managed aws/ebs key; encryption is enforced either way."
  default     = ""

  validation {
    condition     = var.kms_key_arn == "" || can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be empty or a valid KMS key ARN."
  }
}

variable "health_check_grace_period" {
  type        = number
  description = "Seconds the ASG waits after launch before applying ELB health checks."
  default     = 180

  validation {
    condition     = var.health_check_grace_period >= 60
    error_message = "health_check_grace_period must allow at least 60 seconds for cloud-init to install and start nginx."
  }
}

variable "enable_ssm" {
  type        = bool
  description = "Attach the AmazonSSMManagedInstanceCore policy so operators use Session Manager instead of SSH on port 22."
  default     = true
}
