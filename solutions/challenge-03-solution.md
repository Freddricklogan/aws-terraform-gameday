# Challenge 3 Solution: Fix the Auto Scaling and Load Balancer

## Problem
Load balancer returns 503. When instances are terminated, they are not replaced.

## Root Cause
The ASG uses EC2 health checks (only checks if VM is running) and is never attached to the ALB target group.

## Fix 1: Change health check type

```hcl
resource "aws_autoscaling_group" "challenge3" {
  # ...
  health_check_type = "ELB"  # Changed from "EC2"
  # ...
}
```

**Why**:
- **EC2 health check**: Only verifies the virtual machine is running. If nginx crashes but the OS is fine, the ASG thinks everything is healthy.
- **ELB health check**: The ALB actively sends HTTP requests to port 80. If nginx doesn't respond, the ASG marks it unhealthy and replaces it.

## Fix 2: Attach ASG to load balancer

```hcl
resource "aws_autoscaling_attachment" "challenge3" {
  autoscaling_group_name = aws_autoscaling_group.challenge3.id
  lb_target_group_arn    = aws_lb_target_group.challenge3.arn
}
```

**Why**: The ASG manages instances and the ALB distributes traffic, but they don't know about each other. The `aws_autoscaling_attachment` registers ASG instances with the ALB target group so the ALB knows where to send traffic.

Without this attachment:
- ALB has an empty target group -> 503
- ASG creates instances but ALB doesn't know they exist

## Lesson
The ASG and ALB are separate systems. Creating both doesn't connect them. You need the explicit attachment resource. This is another case of the **attach pattern**.
