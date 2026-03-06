# Troubleshooting Guide

## The Attach Pattern (90% of Game Day Issues)

Most broken infrastructure comes from **resources that exist but aren't connected**.

### Checklist: Is Everything Attached?

- [ ] Route table associated as main route table for the VPC
- [ ] Route table associated with each subnet
- [ ] Internet gateway attached to VPC
- [ ] Security group attached to instances (via launch template)
- [ ] Security group has both ingress AND egress rules
- [ ] Launch template attached to Auto Scaling Group
- [ ] Auto Scaling Group attached to load balancer target group
- [ ] Listener attached to load balancer
- [ ] Target group references correct VPC
- [ ] Subnets reference correct VPC

## Common Issues and Fixes

### "I can't reach my web server"

1. **Check security group egress**: Do you have an egress rule allowing all outbound?
   ```hcl
   resource "aws_vpc_security_group_egress_rule" "all" {
     security_group_id = aws_security_group.web.id
     cidr_ipv4         = "0.0.0.0/0"
     ip_protocol       = "-1"
   }
   ```

2. **Check route table association**: Is your custom route table the main one?
   ```hcl
   resource "aws_main_route_table_association" "main" {
     vpc_id         = aws_vpc.main.id
     route_table_id = aws_route_table.public.id
   }
   ```

3. **Check subnet route table association**: Each subnet needs its own association
4. **Check internet gateway**: Is it attached to the VPC?
5. **Check `map_public_ip_on_launch`**: Subnets need this to be `true` for public access

### "terraform apply fails with dependency error"

Terraform usually resolves dependencies automatically, but sometimes you need explicit depends_on:
```hcl
resource "aws_autoscaling_group" "web" {
  depends_on = [aws_internet_gateway.gw]
  # ...
}
```

### "Resources created but load balancer returns 502/503"

- Instances may still be booting. Wait 2-3 minutes for health checks to pass.
- Check the user_data script (install-env.sh) for errors.
- Verify the target group health check path matches what your server serves.

### "terraform destroy gets stuck"

- Auto Scaling Group must scale to 0 before instances can be terminated
- Load balancer takes ~2 minutes to deregister targets
- If stuck over 5 minutes, check the AWS Console for stuck resources

### "Access denied" errors

- Verify your IAM user has the required policies
- Check that `aws configure` has the correct access key and secret key
- Verify the region matches your terraform.tfvars

## Debugging Commands

```bash
# Check current AWS identity
aws sts get-caller-identity

# List running EC2 instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=gameday-prep" --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}"

# Check load balancer status
aws elbv2 describe-load-balancers --names gameday-prep-alb

# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check VPC and subnets
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=gameday-prep"
aws ec2 describe-subnets --filters "Name=tag:Name,Values=gameday-prep"

# Check route tables
aws ec2 describe-route-tables --filters "Name=tag:Name,Values=gameday-prep"

# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=gameday-prep"

# Terraform state inspection
terraform state list
terraform state show aws_vpc.main
terraform state show aws_autoscaling_group.web
```
