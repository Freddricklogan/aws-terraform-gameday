# =============================================================================
# ALB module -- the only internet-facing component in the stack.
#
# Security posture:
#   * SG ingress: only the listener port, only from var.ingress_cidrs
#   * SG egress:  only var.app_port, only to the application SG (no 0.0.0.0/0)
#   * Access logs: mandatory, delivered to the observability bucket
#   * HTTP -> HTTPS redirect whenever an ACM certificate is supplied
# =============================================================================

locals {
  https_enabled = var.certificate_arn != ""
  listener_port = local.https_enabled ? 443 : 80
  alarms_on     = var.alarm_topic_arn != ""
}

# -----------------------------------------------------------------------------
# Security groups -- two of them, referencing each other by ID
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb"
  description = "Ingress from approved CIDRs to the ALB listener; egress only to the application tier."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-alb"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  # checkov:skip=CKV2_AWS_5:Attached by the compute module, which receives this ID through module.alb.app_security_group_id. Cross-module attachment is invisible to the scanner.
  name        = "${var.name_prefix}-app"
  description = "Application tier. Ingress only from the ALB security group; egress for package installs via NAT."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-app"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- ALB ingress: the listener port only -------------------------------------
resource "aws_vpc_security_group_ingress_rule" "alb_listener" {
  # checkov:skip=CKV_AWS_260:A public web tier is intentionally reachable from 0.0.0.0/0 on the listener port; narrow it via var.ingress_cidrs for internal environments.
  for_each = toset(var.ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "Client traffic to the ALB listener"
  cidr_ipv4         = each.value
  from_port         = local.listener_port
  to_port           = local.listener_port
  ip_protocol       = "tcp"
}

# Port 80 stays open only to carry the redirect to 443.
resource "aws_vpc_security_group_ingress_rule" "alb_redirect" {
  # checkov:skip=CKV_AWS_260:Port 80 exists solely to issue an HTTP 301 to HTTPS; no application traffic is served on it.
  for_each = local.https_enabled ? toset(var.ingress_cidrs) : toset([])

  security_group_id = aws_security_group.alb.id
  description       = "HTTP redirect to HTTPS"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# --- ALB egress: to the application SG only, on the app port -----------------
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests to the application tier"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# --- App ingress: from the ALB SG only ---------------------------------------
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  # checkov:skip=CKV_AWS_260:Not an open rule. The source is referenced_security_group_id (the ALB security group), not a CIDR; the scanner matches on the port alone.
  security_group_id            = aws_security_group.app.id
  description                  = "Application traffic from the load balancer only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# --- App egress: HTTPS + HTTP for package installs through the NAT gateway ---
# Note: no port 22 anywhere. Operator access is Session Manager (see compute).
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "Package repositories and AWS API endpoints over TLS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "Ubuntu archive mirrors that still serve plain HTTP with signed packages"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# -----------------------------------------------------------------------------
# Load balancer
# -----------------------------------------------------------------------------
resource "aws_lb" "this" {
  # checkov:skip=CKV_AWS_150:Deletion protection is var.enable_deletion_protection, default false so that `make destroy` ends a Game Day at zero cost. Set it to true for any long-lived environment.
  # checkov:skip=CKV2_AWS_28:No WAF in front of this ALB. Accepted, documented residual risk for a teaching stack with no user data; see AUDIT.md "Residual risks".
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true
  idle_timeout               = 60
  desync_mitigation_mode     = "defensive"

  access_logs {
    enabled = true
    bucket  = var.access_logs_bucket
    prefix  = var.access_logs_prefix
  }

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "this" {
  # checkov:skip=CKV_AWS_378:TLS is terminated at the load balancer. Backend traffic is plain HTTP inside private subnets, reachable only from the ALB security group. End-to-end TLS needs per-instance certificates and is out of scope.
  name        = "${var.name_prefix}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-299"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
  }

  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = {
    Name = "${var.name_prefix}-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS listener -- created only when a certificate is supplied.
resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = {
    Name = "${var.name_prefix}-https"
  }
}

# Port 80: a redirect when TLS is on, the service listener when it is not.
resource "aws_lb_listener" "http" {
  # checkov:skip=CKV_AWS_2:Without an ACM certificate this training stack serves HTTP; set var.certificate_arn and this listener becomes a 301 redirect to HTTPS.
  # checkov:skip=CKV_AWS_103:TLS policy is enforced on the HTTPS listener, which only exists when a certificate is supplied.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = local.https_enabled ? "redirect" : "forward"
    target_group_arn = local.https_enabled ? null : aws_lb_target_group.this.arn

    dynamic "redirect" {
      for_each = local.https_enabled ? [1] : []

      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  tags = {
    Name = "${var.name_prefix}-http"
  }
}

# -----------------------------------------------------------------------------
# Alarms -- the ALB tells you before a user does
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count = local.alarms_on ? 1 : 0

  alarm_name          = "${var.name_prefix}-unhealthy-hosts"
  alarm_description   = "One or more targets are failing the ALB health check."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.unhealthy_host_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.this.arn_suffix
  }

  alarm_actions = [var.alarm_topic_arn]
  ok_actions    = [var.alarm_topic_arn]

  tags = {
    Name = "${var.name_prefix}-unhealthy-hosts"
  }
}

resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  count = local.alarms_on ? 1 : 0

  alarm_name          = "${var.name_prefix}-target-5xx"
  alarm_description   = "The application tier is returning 5xx responses through the ALB."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }

  alarm_actions = [var.alarm_topic_arn]

  tags = {
    Name = "${var.name_prefix}-target-5xx"
  }
}
