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

Networking is the foundation everything else runs on. If the network is broken, nothing works -- instances can't reach the internet, load balancers can't reach instances, and you'll see timeouts with no useful error messages. Based on the practice challenges in this repo, networking issues (route tables, subnet associations, internet gateways) are the most common and hardest to debug because they fail silently.

- VPC creation and configuration
- Subnet design and CIDR block allocation
- Route tables and associations
- Internet gateways
- Understanding public vs private subnets

### Security

Security groups are AWS's firewall, and they default to blocking everything. The critical thing to understand is that security groups are stateful for existing connections but you still need explicit rules in both directions. The most common trap: you add an ingress rule for port 80, forget the egress rule, and HTTP requests arrive at your server but responses never leave. There's no error -- the request just times out.

- Security group rules (ingress and egress)
- The egress trap (forgetting outbound rules)
- IAM permissions and policies
- Key pairs for SSH access

### Compute

The compute layer is where your actual application runs. Launch templates define what each instance looks like (AMI, instance type, security group, bootstrap script), and the Auto Scaling Group manages how many instances are running. If the launch template is misconfigured -- wrong AMI, missing user_data, wrong security group -- every instance the ASG creates will be broken. Know how to read a launch template and verify each field.

- Launch templates
- Auto Scaling Groups (desired, min, max)
- Health checks and instance replacement
- User data bootstrap scripts

### Load Balancing

The Application Load Balancer is the single entry point for all user traffic. It distributes requests across healthy instances and stops sending traffic to unhealthy ones. The key relationships to understand: the listener defines what port to accept traffic on, the target group defines which instances receive traffic, and the health check defines how the ALB determines if an instance is alive. If any of these are misconfigured, you get 502, 503, or 504 errors.

- Application Load Balancer setup
- Target groups and health checks
- Listeners and forwarding rules
- Attaching ASG to ALB

### Terraform Operations

Knowing Terraform commands is table stakes -- `init`, `plan`, `apply`, `destroy`. The real skill is reading `terraform plan` output to understand what Terraform is about to do before you approve it. During Game Day, `terraform state list` and `terraform state show` are your best friends for understanding what currently exists. If you're not sure whether a resource was created, check the state before re-running apply.

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
