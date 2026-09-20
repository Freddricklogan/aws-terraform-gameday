# =============================================================================
# Plan-time assertions on the security posture of each module.
#
# Each `run` block re-roots Terraform at a single module so that the module's
# own resources are addressable, then asserts on the planned values. No AWS
# credentials, no API calls, no cost: `mock_provider` answers every read.
#
# These are the controls a reviewer would otherwise have to take on trust.
# If someone deletes `http_tokens = "required"`, this file goes red.
# =============================================================================

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-2a", "us-east-2b", "us-east-2c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "000000000000"
      arn        = "arn:aws:iam::000000000000:role/mock"
      user_id    = "AIDAMOCK"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-east-2"
    }
  }

  mock_data "aws_elb_service_account" {
    defaults = {
      arn = "arn:aws:iam::000000000000:root"
      id  = "000000000000"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-00000000000000000"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    }
  }
}

# -----------------------------------------------------------------------------
# Network: public subnets carry no workloads, private subnets carry no public IPs
# -----------------------------------------------------------------------------
run "network_subnets_are_not_auto_public" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name_prefix = "gameday-lab"
    vpc_cidr    = "10.0.0.0/16"
    az_count    = 3
  }

  assert {
    condition     = length(aws_subnet.public) == 3 && length(aws_subnet.private) == 3
    error_message = "Expected one public and one private subnet per availability zone."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == false])
    error_message = "Public subnets must not auto-assign public IPs: only the ALB belongs there."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.private : s.map_public_ip_on_launch == false])
    error_message = "Private subnets must never auto-assign public IPs."
  }

  assert {
    condition     = length(aws_route_table_association.public) == 3 && length(aws_route_table_association.private) == 3
    error_message = "Every subnet must be explicitly associated with a route table (the Game Day attach pattern)."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "DNS hostnames must be enabled or the ALB target health checks cannot resolve names."
  }
}

run "network_enables_flow_logs_when_sink_supplied" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name_prefix              = "gameday-lab"
    vpc_cidr                 = "10.0.0.0/16"
    az_count                 = 2
    flow_log_destination_arn = "arn:aws:logs:us-east-2:000000000000:log-group:/aws/vpc/gameday-lab/flow-logs"
    flow_log_role_arn        = "arn:aws:iam::000000000000:role/gameday-lab-flow-logs"
  }

  assert {
    condition     = length(aws_flow_log.this) == 1
    error_message = "A flow log must be created whenever a destination and role are supplied."
  }

  assert {
    condition     = aws_flow_log.this[0].traffic_type == "ALL"
    error_message = "Flow logs must capture ACCEPT and REJECT traffic, not just one of them."
  }
}

run "network_single_nat_gateway_is_cost_bounded" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name_prefix        = "gameday-lab"
    vpc_cidr           = "10.0.0.0/16"
    az_count           = 3
    enable_nat_gateway = true
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway must collapse NAT to one gateway; three NAT gateways is the classic surprise bill."
  }

  assert {
    condition     = length(aws_route.private_default) == 3
    error_message = "Every private route table still needs its own default route to the shared NAT gateway."
  }
}

# -----------------------------------------------------------------------------
# Compute: IMDSv2, encryption, no public IP, ELB health checks
# -----------------------------------------------------------------------------
run "compute_requires_imdsv2_and_encrypted_storage" {
  command = plan

  module {
    source = "./modules/compute"
  }

  variables {
    name_prefix        = "gameday-lab"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    security_group_ids = ["sg-00000000000000001"]
    target_group_arn   = "arn:aws:elasticloadbalancing:us-east-2:000000000000:targetgroup/gameday-lab-tg/0123456789abcdef"
  }

  assert {
    condition     = aws_launch_template.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required; IMDSv1 turns any SSRF into stolen instance credentials."
  }

  assert {
    condition     = aws_launch_template.this.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "The metadata hop limit must be 1 so containers on the host cannot reach the metadata service."
  }

  assert {
    condition     = tobool(aws_launch_template.this.block_device_mappings[0].ebs[0].encrypted) == true
    error_message = "The root EBS volume must be encrypted at rest."
  }

  assert {
    condition     = tobool(aws_launch_template.this.network_interfaces[0].associate_public_ip_address) == false
    error_message = "Application instances must never receive a public IP address."
  }

  assert {
    condition     = aws_launch_template.this.key_name == null || aws_launch_template.this.key_name == ""
    error_message = "No SSH key pair should be attached: operator access is Session Manager."
  }
}

run "compute_registers_with_the_target_group" {
  command = plan

  module {
    source = "./modules/compute"
  }

  variables {
    name_prefix        = "gameday-lab"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    security_group_ids = ["sg-00000000000000001"]
    target_group_arn   = "arn:aws:elasticloadbalancing:us-east-2:000000000000:targetgroup/gameday-lab-tg/0123456789abcdef"
    min_size           = 2
    max_size           = 4
    desired_capacity   = 2
  }

  assert {
    condition     = contains(aws_autoscaling_group.this.target_group_arns, "arn:aws:elasticloadbalancing:us-east-2:000000000000:targetgroup/gameday-lab-tg/0123456789abcdef")
    error_message = "The ASG must be attached to the target group, otherwise the ALB serves 503s."
  }

  assert {
    condition     = aws_autoscaling_group.this.health_check_type == "ELB"
    error_message = "Health check type must be ELB: an EC2 check cannot see a dead web server on a live VM."
  }

  assert {
    condition     = length(aws_autoscaling_group.this.vpc_zone_identifier) >= 2
    error_message = "The ASG must span at least two availability zones."
  }
}

# -----------------------------------------------------------------------------
# ALB: internet-facing but least-privilege, logged, and TLS-capable
# -----------------------------------------------------------------------------
run "alb_is_logged_and_hardened" {
  command = plan

  module {
    source = "./modules/alb"
  }

  variables {
    name_prefix        = "gameday-lab"
    vpc_id             = "vpc-00000000000000001"
    public_subnet_ids  = ["subnet-00000000000000001", "subnet-00000000000000002"]
    access_logs_bucket = "gameday-lab-access-logs-000000000000-us-east-2"
  }

  assert {
    condition     = aws_lb.this.internal == false
    error_message = "This is the public entry point; an internal ALB produces the classic Game Day 504."
  }

  assert {
    condition     = aws_lb.this.access_logs[0].enabled == true
    error_message = "ALB access logging must be enabled: it is the only record of who reached the edge."
  }

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "Invalid header fields must be dropped to blunt request-smuggling attempts."
  }

  assert {
    condition     = aws_lb_target_group.this.health_check[0].matcher == "200-299"
    error_message = "Health checks must accept only 2xx responses."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.alb_to_app.cidr_ipv4 == null && aws_vpc_security_group_egress_rule.alb_to_app.cidr_ipv6 == null
    error_message = "ALB egress must target the application security group, not 0.0.0.0/0."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.cidr_ipv4 == null && aws_vpc_security_group_ingress_rule.app_from_alb.cidr_ipv6 == null
    error_message = "Application ingress must come from the ALB security group only."
  }
}

run "alb_redirects_http_to_https_when_a_certificate_exists" {
  command = plan

  module {
    source = "./modules/alb"
  }

  variables {
    name_prefix        = "gameday-lab"
    vpc_id             = "vpc-00000000000000001"
    public_subnet_ids  = ["subnet-00000000000000001", "subnet-00000000000000002"]
    access_logs_bucket = "gameday-lab-access-logs-000000000000-us-east-2"
    certificate_arn    = "arn:aws:acm:us-east-2:000000000000:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "An HTTPS listener must exist when a certificate is supplied."
  }

  assert {
    condition     = aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "The HTTPS listener must use a TLS 1.2+ security policy."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "redirect"
    error_message = "Port 80 must redirect to HTTPS once TLS is available."
  }
}
