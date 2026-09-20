variable "name_prefix" {
  type        = string
  description = "Prefix applied to the Name tag of every network resource."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-32 chars, lowercase alphanumeric or hyphen, and must not start or end with a hyphen."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC. Must be a private RFC 1918 range."

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.0.0.0/16."
  }

  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "vpc_cidr prefix length must be between /16 and /24 so the module can carve public and private subnets."
  }

  validation {
    condition = anytrue([
      startswith(var.vpc_cidr, "10."),
      startswith(var.vpc_cidr, "192.168."),
      can(regex("^172\\.(1[6-9]|2[0-9]|3[01])\\.", var.vpc_cidr)),
    ])
    error_message = "vpc_cidr must be inside RFC 1918 private space (10/8, 172.16/12 or 192.168/16)."
  }
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to spread the tiers across."
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4 && floor(var.az_count) == var.az_count
    error_message = "az_count must be a whole number between 2 and 4; two AZs is the minimum for a highly available ALB."
  }
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Create NAT gateways so private-subnet instances can reach the internet for package installs."
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Cost control: route every private subnet through one NAT gateway instead of one per AZ. Not recommended for production."
  default     = true
}

variable "flow_log_destination_arn" {
  type        = string
  description = "CloudWatch Logs group ARN that VPC flow logs are delivered to. Empty string disables flow logs (not recommended)."
  default     = ""
}

variable "flow_log_role_arn" {
  type        = string
  description = "IAM role ARN that grants the VPC flow log service permission to write to CloudWatch Logs."
  default     = ""
}

variable "enable_flow_logs" {
  type        = bool
  description = "Explicitly enable or disable VPC flow logs. Leave null to derive from flow_log_destination_arn/flow_log_role_arn. The root module sets this so that count depends only on plan-time-known input, never on an apply-time attribute."
  default     = null
}
