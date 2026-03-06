# Challenge 5 Solution: Fix the Load Balancer

## Problem
Instances work fine individually (curl localhost:80 succeeds), but the ALB URL returns 504 Gateway Timeout.

## Root Cause
The ALB is set to internal (not internet-facing) and the listener is on the wrong port/protocol.

## Fix 1: Make ALB external

```hcl
resource "aws_lb" "challenge5" {
  # ...
  internal = false  # Changed from true
  # ...
}
```

**Why**: An internal load balancer only gets a private IP address, accessible only from within the VPC. External users on the internet can't route to it. For a public web application, `internal` must be `false`.

## Fix 2: Fix listener port and protocol

```hcl
resource "aws_lb_listener" "challenge5" {
  load_balancer_arn = aws_lb.challenge5.arn
  port              = 80     # Changed from 443
  protocol          = "HTTP" # Changed from "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.challenge5.arn
  }
}
```

**Why**: The listener was configured for HTTPS on port 443, but:
1. Our server only runs HTTP on port 80
2. HTTPS requires an SSL/TLS certificate which isn't configured
3. Without a certificate, the ALB can't terminate SSL and the connection fails

## Lesson
The load balancer has its own configuration independent of the instances behind it. Even if instances are healthy, a misconfigured ALB will prevent all traffic. Check: internal vs external, listener port, listener protocol, and that the target group health check matches what the server actually serves.
