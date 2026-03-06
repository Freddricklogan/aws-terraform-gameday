# Challenge 6 Solution: Full Stack Debug

## Problem
Load balancer URL times out completely. Nothing works.

## All 4 Bugs

### Bug 1: No route table associations
The route table has the correct 0.0.0.0/0 -> IGW route, but it's never associated with the subnets.

```hcl
resource "aws_main_route_table_association" "challenge6" {
  vpc_id         = aws_vpc.challenge6.id
  route_table_id = aws_route_table.challenge6.id
}

resource "aws_route_table_association" "challenge6_a" {
  subnet_id      = aws_subnet.challenge6_a.id
  route_table_id = aws_route_table.challenge6.id
}

resource "aws_route_table_association" "challenge6_b" {
  subnet_id      = aws_subnet.challenge6_b.id
  route_table_id = aws_route_table.challenge6.id
}
```

### Bug 2: No HTTP ingress rule
The security group only allows SSH (port 22). HTTP (port 80) is completely blocked.

```hcl
resource "aws_vpc_security_group_ingress_rule" "challenge6_http" {
  security_group_id = aws_security_group.challenge6.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
```

### Bug 3: No ASG-to-ALB attachment
The ASG creates instances but they never register with the ALB target group.

```hcl
resource "aws_autoscaling_attachment" "challenge6" {
  autoscaling_group_name = aws_autoscaling_group.challenge6.id
  lb_target_group_arn    = aws_lb_target_group.challenge6.arn
}
```

### Bug 4: (Same as Bug 2)
The missing HTTP ingress rule means even after fixing the attachment, ALB health checks fail because port 80 is blocked by the security group. Both bugs 2 and 3 must be fixed together.

## Debugging Strategy

1. **Start from the outside in**: Can you reach the ALB? -> Check ALB is external, listener port is correct
2. **Check the target group**: Are instances registered? -> Check ASG attachment
3. **Check health checks**: Are instances healthy? -> Check security group allows port 80
4. **Check routing**: Can instances reach the internet? -> Check route table associations
5. **Check the instances**: Is nginx running? -> Check user_data in launch template

## Lesson
Real-world debugging requires checking every layer of the stack. Use `terraform state list` to see what exists, then verify each connection between resources.
