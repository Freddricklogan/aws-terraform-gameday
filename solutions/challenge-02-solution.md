# Challenge 2 Solution: Fix the Security Group

## Problem
Web server is running, routing is correct, but HTTP requests time out. SSH also fails despite having an ingress rule.

## Root Cause
Two issues: the HTTP rule is on the wrong port, and there's no egress rule at all.

## Fix 1: Correct the HTTP port

```hcl
resource "aws_vpc_security_group_ingress_rule" "challenge2_http" {
  security_group_id = aws_security_group.challenge2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80   # Changed from 443
  ip_protocol       = "tcp"
  to_port           = 80   # Changed from 443
}
```

**Why**: Our web server (nginx) listens on port 80 (HTTP). Port 443 is for HTTPS, which requires SSL certificates we haven't configured.

## Fix 2: Add egress rule

```hcl
resource "aws_vpc_security_group_egress_rule" "challenge2_all" {
  security_group_id = aws_security_group.challenge2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
```

**Why**: AWS security groups deny all traffic by default in both directions. Without an egress rule, incoming requests reach the server, the server generates a response, but the response is blocked from leaving. This causes a **silent timeout** with no error message -- the request just hangs.

## Lesson
The egress trap is the hardest bug to diagnose because there's no error. The request arrives, the server processes it, but the response never makes it back. Always check both ingress AND egress rules.
