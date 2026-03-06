# Game Day Quick Reference Card

Print this or keep it open during the competition.

---

## Terraform Commands

```bash
terraform init          # Download providers (run once)
terraform validate      # Check syntax
terraform plan          # Preview changes
terraform apply         # Deploy (type 'yes')
terraform destroy       # Tear down (type 'yes')
terraform fmt           # Auto-format code
terraform state list    # List managed resources
terraform state show X  # Inspect a resource
terraform output        # Show output values
```

## AWS CLI Quick Checks

```bash
# Identity
aws sts get-caller-identity

# EC2 instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{ID:InstanceId,IP:PublicIpAddress,AZ:Placement.AvailabilityZone}" \
  --output table

# VPC
aws ec2 describe-vpcs --query "Vpcs[].{ID:VpcId,CIDR:CidrBlock,Name:Tags[?Key=='Name']|[0].Value}" --output table

# Subnets
aws ec2 describe-subnets --query "Subnets[].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}" --output table

# Route tables
aws ec2 describe-route-tables --query "RouteTables[].{ID:RouteTableId,Routes:Routes[].{Dest:DestinationCidrBlock,Target:GatewayId}}" --output json

# Security groups
aws ec2 describe-security-groups --query "SecurityGroups[].{Name:GroupName,ID:GroupId,Ingress:IpPermissions,Egress:IpPermissionsEgress}" --output json

# Load balancers
aws elbv2 describe-load-balancers --query "LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" --output table

# Target health
aws elbv2 describe-target-health --target-group-arn <ARN> --output table
```

## The Attach Checklist

When something doesn't work, check this list top-to-bottom:

| Check | Resource | Attached To |
|-------|----------|-------------|
| 1 | Internet Gateway | VPC |
| 2 | Route Table (0.0.0.0/0 -> IGW) | VPC (as main) |
| 3 | Route Table Association | Each Subnet |
| 4 | Subnet: map_public_ip_on_launch | true |
| 5 | Security Group: HTTP ingress | Port 80 |
| 6 | Security Group: egress | All traffic (-1) |
| 7 | Launch Template: user_data | Bootstrap script |
| 8 | Launch Template: security group | Custom SG |
| 9 | ASG: vpc_zone_identifier | Subnets |
| 10 | ASG: health_check_type | "ELB" (not "EC2") |
| 11 | ASG Attachment | Target Group |
| 12 | ALB: internal | false (for public) |
| 13 | Listener: port | 80 (HTTP) |
| 14 | Target Group: VPC | Correct VPC |

## Common Errors

| Symptom | Likely Cause |
|---------|-------------|
| Connection timed out | Missing route table association or egress rule |
| 502 Bad Gateway | Instances still booting (wait 2-3 min) |
| 503 Service Unavailable | ASG not attached to target group |
| 504 Gateway Timeout | ALB is internal=true or listener on wrong port |
| "Access Denied" in terraform | IAM permissions missing |
| "No valid credential sources" | Run `aws configure` |
| Health checks failing | Security group blocks port 80 or no user_data |

## Resource Reference Syntax

```hcl
aws_vpc.main.id                           # VPC ID
aws_subnet.public[0].id                   # First subnet ID
aws_subnet.public[*].id                   # All subnet IDs (list)
aws_security_group.web.id                 # Security group ID
aws_lb.web.arn                            # Load balancer ARN
aws_lb.web.dns_name                       # Load balancer DNS
aws_lb_target_group.web.arn               # Target group ARN
aws_launch_template.web.id                # Launch template ID
aws_autoscaling_group.web.name            # ASG name
data.aws_ami.ubuntu.id                    # Ubuntu AMI ID
data.aws_availability_zones.available.names  # AZ list
var.instance_type                         # Variable value
```

## CIDR Quick Math

| CIDR | IPs | Example |
|------|-----|---------|
| /16 | 65,536 | VPC (10.0.0.0/16) |
| /20 | 4,096 | Large subnet |
| /24 | 256 | Standard subnet (10.0.0.0/24) |
| /28 | 16 | Minimum AWS subnet |

Formula: `2^(32 - prefix) = number of IPs`

## Key Ports

| Port | Protocol | Service |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP |
| 443 | TCP | HTTPS |
| -1 | All | All traffic (egress) |
