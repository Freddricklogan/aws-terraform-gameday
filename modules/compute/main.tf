# =============================================================================
# Compute module -- launch template + Auto Scaling group in the private tier.
#
# Hardening that the original Game Day configuration did not have:
#   * IMDSv2 required (http_tokens = "required", hop limit 1)
#   * Encrypted gp3 root volume, delete-on-termination
#   * No public IP, no SSH: operator access is AWS Systems Manager
#   * ELB health checks, instance refresh on template change
#   * Detailed monitoring so 1-minute alarms have 1-minute data
# =============================================================================

data "aws_ssm_parameter" "ubuntu_ami" {
  # Canonical publishes the current Ubuntu 22.04 LTS AMI id per region in SSM.
  # This is both faster and more reproducible than a most_recent AMI filter.
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

locals {
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    app_port = var.app_port
    project  = var.name_prefix
  })
}

# -----------------------------------------------------------------------------
# Instance role -- Session Manager only, no inline wildcards
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name_prefix}-instance"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = {
    Name = "${var.name_prefix}-instance"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name_prefix}-instance"
  role = aws_iam_role.instance.name
}

# -----------------------------------------------------------------------------
# Launch template
# -----------------------------------------------------------------------------
resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-"
  image_id      = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = var.instance_type
  user_data     = base64encode(local.user_data)

  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  # No key_name: there is no SSH path into these instances by design.
  # ATTACHMENT 4 of 4 -- omit security_groups here and every instance silently
  # joins the VPC default security group instead of the application one.
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = var.security_group_ids
    delete_on_termination       = true
  }

  # IMDSv2 required. hop limit 1 stops a containerised process on the host
  # from reaching the metadata service and stealing the instance role.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn == "" ? null : var.kms_key_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.name_prefix}-app"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.name_prefix}-app-root"
    }
  }

  tags = {
    Name = "${var.name_prefix}-lt"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling group
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group" "this" {
  name_prefix         = "${var.name_prefix}-"
  vpc_zone_identifier = var.private_subnet_ids

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  # ELB, not EC2: a running VM with a dead nginx is still a failed target.
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period
  default_cooldown          = 60
  capacity_rebalance        = true

  # ATTACHMENT 3 of 4 -- the single line that prevents "ALB returns 503".
  target_group_arns = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = var.health_check_grace_period
    }
  }

  # Minimum healthy instances during a scale-in event.
  termination_policies = ["OldestLaunchTemplate", "OldestInstance"]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-app"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Target tracking policy -- scale on CPU rather than on a human noticing
# -----------------------------------------------------------------------------
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name_prefix}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 60
  }
}
