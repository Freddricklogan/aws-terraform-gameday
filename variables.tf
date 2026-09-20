# =============================================================================
# Root variables.
#
# Every variable carries a type, a description and at least one validation
# block. A bad value fails in under a second at plan time instead of halfway
# through an apply, which is exactly the feedback loop a Game Day needs.
# =============================================================================

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-2"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-(central|north|south|east|west|northeast|northwest|southeast|southwest)-[1-9]$", var.aws_region))
    error_message = "aws_region must be a valid region identifier such as us-east-2 or eu-west-1."
  }
}

variable "project" {
  type        = string
  description = "Short project slug used as the prefix of every resource name."
  default     = "gameday"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$", var.project))
    error_message = "project must be 3-20 chars, lowercase alphanumeric or hyphen, not starting or ending with a hyphen."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment. Drives naming, tagging and the CI approval gate."
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: lab, dev, staging, prod."
  }
}

variable "owner" {
  type        = string
  description = "Person or team accountable for these resources. Appears on every resource via default_tags."
  default     = "Freddrick Logan"

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty: untagged resources become nobody's problem and nobody's bill."
  }
}

variable "cost_center" {
  type        = string
  description = "Cost allocation tag value."
  default     = "education"

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center must not be empty."
  }
}

variable "data_classification" {
  type        = string
  description = "Sensitivity of data handled by this stack."
  default     = "public"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "additional_tags" {
  type        = map(string)
  description = "Extra tags merged into default_tags."
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.additional_tags) : !contains(["Name", "Environment", "Project", "Owner"], k)])
    error_message = "additional_tags must not override the reserved tags Name, Environment, Project or Owner."
  }
}

# --- Network -----------------------------------------------------------------

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to use."
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Give private instances outbound internet access through NAT. Disable only if you pre-bake the AMI."
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Cost control: one NAT gateway for all AZs. Set to false for production-grade AZ independence."
  default     = true
}

# --- Compute -----------------------------------------------------------------

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the application tier."
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must look like a valid EC2 instance type, e.g. t3.micro."
  }
}

variable "min_size" {
  type        = number
  description = "Minimum Auto Scaling group size."
  default     = 2

  validation {
    condition     = var.min_size >= 1
    error_message = "min_size must be at least 1."
  }
}

variable "max_size" {
  type        = number
  description = "Maximum Auto Scaling group size."
  default     = 5

  validation {
    condition     = var.max_size >= 1 && var.max_size <= 20
    error_message = "max_size must be between 1 and 20."
  }
}

variable "desired_capacity" {
  type        = number
  description = "Steady-state Auto Scaling group size."
  default     = 3

  validation {
    condition     = var.desired_capacity >= var.min_size && var.desired_capacity <= var.max_size
    error_message = "desired_capacity must fall between min_size and max_size."
  }
}

variable "app_port" {
  type        = number
  description = "Port the application listens on."
  default     = 80

  validation {
    condition     = var.app_port > 0 && var.app_port <= 65535
    error_message = "app_port must be a valid TCP port."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "Customer-managed KMS key for EBS encryption. Empty uses the aws/ebs managed key."
  default     = ""

  validation {
    condition     = var.kms_key_arn == "" || can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be empty or a valid KMS key ARN."
  }
}

# --- Edge --------------------------------------------------------------------

variable "alb_ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the load balancer."
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for c in var.alb_ingress_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in alb_ingress_cidrs must be a valid IPv4 CIDR block."
  }
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN. Set it and the ALB serves HTTPS and redirects HTTP."
  default     = ""

  validation {
    condition     = var.certificate_arn == "" || can(regex("^arn:aws[a-z-]*:acm:", var.certificate_arn))
    error_message = "certificate_arn must be empty or a valid ACM certificate ARN."
  }
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Protect the ALB from deletion. Leave false for Game Day so make destroy works."
  default     = false
}

# --- Observability -----------------------------------------------------------

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention for VPC flow logs."
  default     = 90

  validation {
    condition     = var.log_retention_days >= 30
    error_message = "log_retention_days must be at least 30 so an incident review has something to read."
  }
}

variable "access_log_expiration_days" {
  type        = number
  description = "Days before ALB access log objects expire."
  default     = 90

  validation {
    condition     = var.access_log_expiration_days >= 30
    error_message = "access_log_expiration_days must be at least 30."
  }
}

variable "alarm_email" {
  type        = string
  description = "Optional email address subscribed to the alarm topic."
  default     = ""

  validation {
    condition     = var.alarm_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[a-zA-Z]{2,}$", var.alarm_email))
    error_message = "alarm_email must be empty or a valid email address."
  }
}
