# =============================================================================
# CHALLENGE 6: Full Stack Debug (Boss Level)
#
# SCENARIO: Someone deployed this infrastructure but nothing works.
# The load balancer URL times out completely.
# Find and fix ALL 4 bugs to make it work end-to-end.
#
# This challenge combines issues from earlier challenges.
# No hints are given -- just the buggy code.
# =============================================================================

# --- VPC ---
resource "aws_vpc" "challenge6" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "challenge-06" }
}

# --- Subnet ---
resource "aws_subnet" "challenge6_a" {
  vpc_id                  = aws_vpc.challenge6.id
  cidr_block              = "10.1.0.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
  tags = { Name = "challenge-06-a" }
}

resource "aws_subnet" "challenge6_b" {
  vpc_id                  = aws_vpc.challenge6.id
  cidr_block              = "10.1.16.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true
  tags = { Name = "challenge-06-b" }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "challenge6" {
  vpc_id = aws_vpc.challenge6.id
  tags   = { Name = "challenge-06" }
}

# --- Route Table ---
resource "aws_route_table" "challenge6" {
  vpc_id = aws_vpc.challenge6.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.challenge6.id
  }
  tags = { Name = "challenge-06" }
}

# BUG 1: No route table association with subnets.
#         Traffic from instances has no route to the internet gateway.
#
# FIX: Add aws_route_table_association for each subnet
#      AND/OR set this as the main route table

# --- Security Group ---
resource "aws_security_group" "challenge6" {
  name   = "challenge-06-sg"
  vpc_id = aws_vpc.challenge6.id
  tags   = { Name = "challenge-06" }
}

resource "aws_vpc_security_group_ingress_rule" "challenge6_ssh" {
  security_group_id = aws_security_group.challenge6.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# BUG 2: No HTTP ingress rule. Port 80 is blocked.
#
# FIX: Add an ingress rule for port 80

resource "aws_vpc_security_group_egress_rule" "challenge6_all" {
  security_group_id = aws_security_group.challenge6.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- Launch Template ---
resource "aws_launch_template" "challenge6" {
  name                   = "challenge-06-lt"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  user_data              = filebase64("${path.module}/install-env.sh")
  vpc_security_group_ids = [aws_security_group.challenge6.id]

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "challenge-06" }
  }
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "challenge6" {
  name                = "challenge-06-asg"
  vpc_zone_identifier = [aws_subnet.challenge6_a.id, aws_subnet.challenge6_b.id]
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.challenge6.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "challenge-06"
    propagate_at_launch = true
  }
}

# --- Load Balancer ---
resource "aws_lb" "challenge6" {
  name               = "challenge-06-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.challenge6.id]
  subnets            = [aws_subnet.challenge6_a.id, aws_subnet.challenge6_b.id]
  tags               = { Name = "challenge-06" }
}

resource "aws_lb_target_group" "challenge6" {
  name     = "challenge-06-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.challenge6.id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }

  tags = { Name = "challenge-06" }
}

resource "aws_lb_listener" "challenge6" {
  load_balancer_arn = aws_lb.challenge6.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.challenge6.arn
  }
}

# BUG 3: No autoscaling attachment.
#         The ASG and ALB both exist, but instances never register
#         with the target group. ALB returns 503.
#
# FIX: Add aws_autoscaling_attachment connecting the ASG to the target group

# BUG 4: (Hidden) The security group has no HTTP ingress rule (Bug 2 above).
#         Even after fixing the attachment, the ALB health checks will fail
#         because port 80 is blocked by the security group.
#         Both bugs must be fixed together for the infrastructure to work.
