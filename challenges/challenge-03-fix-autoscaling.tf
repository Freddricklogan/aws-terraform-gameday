# =============================================================================
# CHALLENGE 3: Fix the Auto Scaling and Load Balancer
#
# SCENARIO: VPC, subnets, and security groups all work. Instances are running.
# But the load balancer URL returns 503 Service Unavailable.
# And when instances are terminated, they are not replaced.
#
# HINT: The ASG and ALB exist but aren't properly connected. Find 2 bugs.
# =============================================================================

# Auto Scaling Group -- has an issue
resource "aws_autoscaling_group" "challenge3" {
  name                = "challenge-03-asg"
  vpc_zone_identifier = [aws_subnet.challenge1.id]
  desired_capacity    = 3
  max_size            = 5
  min_size            = 2

  # ============================================================
  # BUG 1: Health check type is "EC2" instead of "ELB".
  #         With EC2 health checks, the ASG only checks if the
  #         VM is running, not if the web server is responding.
  #         When nginx crashes but the VM is alive, the ASG
  #         won't replace it.
  #
  # FIX: Change "EC2" to "ELB"
  # ============================================================
  health_check_type         = "EC2"  # BUG: Should be "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "challenge-03"
    propagate_at_launch = true
  }
}

# Load Balancer and Target Group (these are correct)
resource "aws_lb" "challenge3" {
  name               = "challenge-03-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = [aws_subnet.challenge1.id]
  tags               = { Name = "challenge-03" }
}

resource "aws_lb_target_group" "challenge3" {
  name     = "challenge-03-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.challenge1.id
}

resource "aws_lb_listener" "challenge3" {
  load_balancer_arn = aws_lb.challenge3.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.challenge3.arn
  }
}

# ============================================================
# BUG 2: The ASG is NEVER attached to the load balancer.
#         The ALB exists, the target group exists, instances exist,
#         but instances are not registered with the target group.
#         So the ALB has no targets to forward traffic to -> 503.
#
# FIX: Uncomment this block:
# resource "aws_autoscaling_attachment" "challenge3" {
#   autoscaling_group_name = aws_autoscaling_group.challenge3.id
#   lb_target_group_arn    = aws_lb_target_group.challenge3.arn
# }
# ============================================================
