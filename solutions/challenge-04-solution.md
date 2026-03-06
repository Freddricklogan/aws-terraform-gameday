# Challenge 4 Solution: Fix the Launch Template

## Problem
Instances show a blank page. They're also in the wrong security group.

## Root Cause
The launch template is missing both the user_data bootstrap script and the security group assignment.

## Fix 1: Add user_data

```hcl
resource "aws_launch_template" "challenge4" {
  # ...
  user_data = filebase64("${path.module}/install-env.sh")
  # ...
}
```

**Why**: The `user_data` field runs a script on first boot. Our `install-env.sh` installs nginx and creates the welcome page. Without it, the instance boots as a bare Ubuntu server with nothing listening on port 80.

Note: `filebase64()` is required because AWS expects user_data to be base64-encoded.

## Fix 2: Add security group

```hcl
resource "aws_launch_template" "challenge4" {
  # ...
  vpc_security_group_ids = [aws_security_group.web.id]
  # ...
}
```

**Why**: Without specifying a security group, the instance gets the VPC's default security group which blocks all inbound traffic. Even if nginx were installed, no one could reach it.

## Lesson
The launch template is the blueprint for every instance the ASG creates. If the blueprint is wrong, every instance will be wrong. Always verify: correct AMI, correct instance type, correct security group, correct user_data.
