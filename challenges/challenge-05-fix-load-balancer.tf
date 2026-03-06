# =============================================================================
# CHALLENGE 5: Fix the Load Balancer
#
# SCENARIO: Instances are running and healthy. You can SSH in and curl
# localhost:80 -- nginx responds correctly. But the ALB URL returns
# a 504 Gateway Timeout.
#
# HINT: The load balancer configuration has 2 issues preventing
# traffic from reaching the instances.
# =============================================================================

resource "aws_lb" "challenge5" {
  name               = "challenge-05-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = aws_subnet.public[*].id

  # ============================================================
  # BUG 1: internal = true
  #         An internal load balancer is only accessible from within
  #         the VPC. External users on the internet cannot reach it.
  #         For a public-facing web app, this must be false.
  #
  # FIX: Change true to false
  # ============================================================
  internal = true  # BUG: Should be false

  tags = { Name = "challenge-05" }
}

resource "aws_lb_target_group" "challenge5" {
  name     = "challenge-05-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = { Name = "challenge-05" }
}

resource "aws_lb_listener" "challenge5" {
  load_balancer_arn = aws_lb.challenge5.arn

  # ============================================================
  # BUG 2: Listener is on port 443 (HTTPS) but the server only
  #         runs HTTP on port 80. There is no SSL certificate
  #         configured either. Traffic arrives on 443, but the
  #         ALB can't terminate SSL, so it times out.
  #
  # FIX: Change port from 443 to 80
  #       Change protocol from "HTTPS" to "HTTP"
  # ============================================================
  port     = 443     # BUG: Should be 80
  protocol = "HTTPS" # BUG: Should be "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.challenge5.arn
  }
}
