# Challenge 1 Solution: Fix the Routing

## Problem
Instances cannot reach the internet. Web servers are running but inaccessible externally.

## Root Cause
The route table exists with the correct 0.0.0.0/0 -> IGW route, but it's never connected to anything. The VPC falls back to the default route table which has no internet route.

## Fix 1: Set as main route table

```hcl
resource "aws_main_route_table_association" "challenge1" {
  vpc_id         = aws_vpc.challenge1.id
  route_table_id = aws_route_table.challenge1.id
}
```

**Why**: The VPC has a default route table that only allows local traffic. By making our custom route table the main one, all subnets without an explicit association will use it.

## Fix 2: Associate with subnet

```hcl
resource "aws_route_table_association" "challenge1" {
  subnet_id      = aws_subnet.challenge1.id
  route_table_id = aws_route_table.challenge1.id
}
```

**Why**: Even with a main route table, explicit subnet associations are best practice. They ensure the subnet uses your route table regardless of main route table changes.

## Lesson
Creating a resource is not enough. You must **attach** it. This is the single most common issue in AWS Terraform deployments.
