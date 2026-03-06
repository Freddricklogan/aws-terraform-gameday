variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "us-east-2"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type (t3.micro is free tier eligible)"
  default     = "t3.micro"
}

variable "project_tag" {
  type        = string
  description = "Tag applied to all resources for identification and filtering"
  default     = "gameday-prep"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for each subnet (one per AZ)"
  default     = ["10.0.0.0/24", "10.0.16.0/24", "10.0.32.0/24"]
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of instances in the Auto Scaling group"
  default     = 3
}

variable "min_size" {
  type        = number
  description = "Minimum number of instances in the Auto Scaling group"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of instances in the Auto Scaling group"
  default     = 5
}
