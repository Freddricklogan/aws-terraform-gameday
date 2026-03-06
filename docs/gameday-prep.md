# Game Day Preparation Guide

## Event Details

- **Date**: March 13, 2026
- **Location**: IIT Hub Ballroom
- **Format**: Team-based infrastructure troubleshooting competition
- **Hosts**: HashiCorp representatives + AWS representatives
- **Accounts**: AWS will provide throwaway accounts for the event

## What to Expect

1. **Kickoff**: Teams are onboarded, given access to AWS accounts
2. **Source Code**: You receive a repo with Terraform code containing broken infrastructure
3. **Challenges**: Multiple puzzles to fix -- broken networking, misconfigured security, failed deployments
4. **Scoring**: Points awarded for each fix. Race against other teams.
5. **No hand-holding**: No step-by-step instructions. You, your team, and AI tools.

## Key Skills to Practice

### Networking (Highest Priority)
- VPC creation and configuration
- Subnet design and CIDR block allocation
- Route tables and associations
- Internet gateways
- Understanding public vs private subnets

### Security
- Security group rules (ingress and egress)
- The egress trap (forgetting outbound rules)
- IAM permissions and policies
- Key pairs for SSH access

### Compute
- Launch templates
- Auto Scaling Groups (desired, min, max)
- Health checks and instance replacement
- User data bootstrap scripts

### Load Balancing
- Application Load Balancer setup
- Target groups and health checks
- Listeners and forwarding rules
- Attaching ASG to ALB

### Terraform Operations
- `terraform init`, `validate`, `plan`, `apply`, `destroy`
- Reading error messages and plan output
- Understanding resource dependencies
- Using `terraform state` commands for inspection

## Study Plan

### Week Before (Now)
- Deploy the full infrastructure in this repo at least once
- Practice `terraform destroy` and redeploy
- Read through the Terraform AWS Provider docs for VPC, EC2, ALB, ASG
- Try the practice challenges in the `challenges/` directory

### Day Before
- Review the troubleshooting guide
- Make sure your AWS CLI is configured and working
- Have the Terraform docs bookmarked
- Charge your laptop

### Day Of
- Bring your laptop with everything pre-installed
- Have this repo cloned and ready
- Stay calm -- it's applied troubleshooting, not a test
- Communicate with your team constantly
- Use AI tools when stuck
- Check attachments first when something doesn't work

## Bookmarks to Have Ready

1. Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
2. AWS VPC Docs: https://docs.aws.amazon.com/vpc/latest/userguide/
3. AWS EC2 Docs: https://docs.aws.amazon.com/ec2/
4. AWS ALB Docs: https://docs.aws.amazon.com/elasticloadbalancing/
5. Terraform Language Reference: https://developer.hashicorp.com/terraform/language
6. AWS CLI Reference: https://docs.aws.amazon.com/cli/latest/reference/
