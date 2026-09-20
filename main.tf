# =============================================================================
# Root composition.
#
# This file wires four modules together and contains no resources of its own.
# Read it top to bottom to understand the whole stack in about ninety seconds:
#
#   observability -> log sinks and the alarm topic (created first, so the
#                    network and the ALB have somewhere to write)
#   network       -> VPC, public subnets (ALB), private subnets (app), NAT
#   alb           -> internet-facing load balancer, both security groups
#   compute       -> launch template + ASG registered with the target group
# =============================================================================

locals {
  name_prefix = "${var.project}-${var.environment}"

  # Applied to every taggable resource through provider default_tags.
  common_tags = merge(
    {
      Project            = var.project
      Environment        = var.environment
      Owner              = var.owner
      CostCenter         = var.cost_center
      DataClassification = var.data_classification
      ManagedBy          = "terraform"
      Repository         = "aws-terraform-gameday"
    },
    var.additional_tags,
  )
}

module "observability" {
  source = "./modules/observability"

  name_prefix                = local.name_prefix
  log_retention_days         = var.log_retention_days
  access_log_expiration_days = var.access_log_expiration_days
  alarm_email                = var.alarm_email
}

module "network" {
  source = "./modules/network"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  flow_log_destination_arn = module.observability.flow_log_group_arn
  flow_log_role_arn        = module.observability.flow_log_role_arn
}

module "alb" {
  source = "./modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids

  ingress_cidrs   = var.alb_ingress_cidrs
  app_port        = var.app_port
  certificate_arn = var.certificate_arn

  access_logs_bucket = module.observability.access_logs_bucket
  access_logs_prefix = module.observability.access_logs_prefix
  alarm_topic_arn    = module.observability.alarm_topic_arn

  health_check_path          = "/healthz"
  enable_deletion_protection = var.enable_deletion_protection
}

module "compute" {
  source = "./modules/compute"

  name_prefix        = local.name_prefix
  private_subnet_ids = module.network.private_subnet_ids
  security_group_ids = [module.alb.app_security_group_id]
  target_group_arn   = module.alb.target_group_arn

  instance_type    = var.instance_type
  app_port         = var.app_port
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  kms_key_arn      = var.kms_key_arn
}
