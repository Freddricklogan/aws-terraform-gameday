# AWS Terraform Infrastructure -- Game Day

## Three-Tier Web Application on AWS with Terraform

This repository contains Terraform Infrastructure as Code (IaC) for deploying a complete three-tier web application on AWS. Built for the **AWS & HashiCorp Terraform Game Day** (March 13, 2026) at Illinois Institute of Technology.

Includes production-ready Terraform configs, 6 hands-on troubleshooting challenges with solutions, reference documentation, automation scripts, and [documented results](#game-day-results----march-13-2026) from the live competition.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [What Gets Deployed](#what-gets-deployed)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Practice Challenges](#practice-challenges)
- [Project Structure](#project-structure)
- [Key Concepts](#key-concepts)
- [Game Day Tips](#game-day-tips)
- [Game Day Results](#game-day-results----march-13-2026)
- [Documentation](#documentation)
- [References](#references)

---

## Architecture Overview

```
                    ┌─────────────────────────────────┐
                    │           Internet               │
                    └────────────┬────────────────────┘
                                 │
                    ┌────────────▼────────────────────┐
                    │     Application Load Balancer    │
                    │         (Port 80 HTTP)           │
                    └────────────┬────────────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                    │
   ┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐
   │   Subnet 2a     │ │   Subnet 2b     │ │   Subnet 2c     │
   │  10.0.0.0/24    │ │  10.0.16.0/24   │ │  10.0.32.0/24   │
   │                  │ │                  │ │                  │
   │  ┌──────────┐   │ │  ┌──────────┐   │ │  ┌──────────┐   │
   │  │ EC2 Inst │   │ │  │ EC2 Inst │   │ │  │ EC2 Inst │   │
   │  │ (nginx)  │   │ │  │ (nginx)  │   │ │  │ (nginx)  │   │
   │  └──────────┘   │ │  └──────────┘   │ │  └──────────┘   │
   └──────────────────┘ └──────────────────┘ └──────────────────┘
            │                    │                    │
   ┌────────────────────────────────────────────────────────────┐
   │                    VPC: 10.0.0.0/16                        │
   │              Route Table + Internet Gateway                │
   └────────────────────────────────────────────────────────────┘
```

## What Gets Deployed

| Resource | Count | Purpose |
|----------|-------|---------|
| VPC | 1 | Custom virtual network (10.0.0.0/16, ~65K IPs) |
| Subnets | 3 | One per availability zone (us-east-2a, 2b, 2c) |
| Internet Gateway | 1 | Outbound internet access |
| Route Table | 1 | Default + local routing |
| Security Group | 1 | Firewall: SSH (22) + HTTP (80) inbound, all outbound |
| Launch Template | 1 | EC2 instance blueprint (Ubuntu, t3.micro, nginx) |
| Auto Scaling Group | 1 | Desired: 3, Min: 2, Max: 5 instances |
| Application Load Balancer | 1 | Distributes HTTP traffic across instances |
| Target Group | 1 | Health-checked instance pool |
| Listener | 1 | HTTP port 80 forwarding |

## Prerequisites

- AWS Account with billing budget set ($20 recommended)
- AWS CLI installed and configured ([setup script](scripts/setup-aws-cli.sh))
- Terraform installed v1.5+ ([setup script](scripts/setup-terraform.sh))
- VS Code with HashiCorp HCL and Terraform extensions
- Linux environment (Ubuntu VM via Parallels, VirtualBox, or WSL)

See [docs/setup-guide.md](docs/setup-guide.md) for detailed step-by-step instructions.

## Quick Start

```bash
# Clone and enter the repo
git clone https://github.com/Freddricklogan/aws-terraform-gameday.git
cd aws-terraform-gameday

# Configure AWS credentials
aws configure
# Enter: Access Key, Secret Key, Region (us-east-2), Output format (json)

# Run pre-flight checks
bash scripts/validate.sh

# Deploy infrastructure
make init
make plan
make apply    # Type 'yes' when prompted (~2-3 minutes)

# Visit the load balancer URL from the output
terraform output load_balancer_dns

# IMPORTANT: Destroy when done to avoid charges
make destroy  # Type 'yes' when prompted
```

Or use individual Terraform commands:

```bash
terraform init       # Download providers
terraform validate   # Check syntax
terraform plan       # Preview changes
terraform apply      # Deploy
terraform destroy    # Tear down
```

## Practice Challenges

6 progressive troubleshooting challenges that mirror real Game Day scenarios. Each contains intentionally broken Terraform code with bugs to find and fix.

| # | Challenge | Difficulty | Bugs | Skills Tested |
|---|-----------|------------|------|---------------|
| 1 | [Fix Routing](challenges/challenge-01-fix-routing.tf) | Beginner | 2 | Route tables, subnet associations |
| 2 | [Fix Security](challenges/challenge-02-fix-security.tf) | Beginner | 2 | Security groups, ingress/egress rules |
| 3 | [Fix Auto Scaling](challenges/challenge-03-fix-autoscaling.tf) | Intermediate | 2 | ASG health checks, ALB attachment |
| 4 | [Fix Launch Template](challenges/challenge-04-fix-launch-template.tf) | Intermediate | 2 | user_data, security group assignment |
| 5 | [Fix Load Balancer](challenges/challenge-05-fix-load-balancer.tf) | Intermediate | 2 | ALB internal/external, listener config |
| 6 | [Full Stack Debug](challenges/challenge-06-full-debug.tf) | Advanced | 4 | All of the above combined |

Solutions are in [solutions/](solutions/) -- try the challenges first before looking.

## Project Structure

```
aws-terraform-gameday/
├── main.tf                  # Core infrastructure (VPC, subnets, ASG, ALB)
├── provider.tf              # AWS provider configuration
├── variables.tf             # Variable definitions (8 configurable params)
├── terraform.tfvars         # Variable values (region, instance type, tags)
├── outputs.tf               # Output values (load balancer URL, VPC ID, etc.)
├── install-env.sh           # EC2 bootstrap script (installs nginx)
├── Makefile                 # Workflow shortcuts (make plan, make apply, etc.)
├── .gitignore               # Excludes state files, .terraform/, IDE files
│
├── docs/
│   ├── setup-guide.md       # Step-by-step environment setup
│   ├── aws-concepts.md      # Core AWS concepts explained
│   ├── terraform-guide.md   # Terraform syntax and commands reference
│   ├── troubleshooting.md   # Common issues and debugging techniques
│   ├── gameday-prep.md      # Game Day strategy, timeline, and tips
│   └── cheat-sheet.md       # Printable quick-reference card
│
├── challenges/
│   ├── challenge-01-fix-routing.tf        # Broken route table
│   ├── challenge-02-fix-security.tf       # Misconfigured security group
│   ├── challenge-03-fix-autoscaling.tf    # Broken ASG/ALB connection
│   ├── challenge-04-fix-launch-template.tf # Missing user_data and SG
│   ├── challenge-05-fix-load-balancer.tf  # Internal ALB + wrong port
│   └── challenge-06-full-debug.tf         # Multi-issue boss challenge
│
├── solutions/
│   ├── challenge-01-solution.md   # Routing fix explained
│   ├── challenge-02-solution.md   # Security fix explained
│   ├── challenge-03-solution.md   # Auto scaling fix explained
│   ├── challenge-04-solution.md   # Launch template fix explained
│   ├── challenge-05-solution.md   # Load balancer fix explained
│   └── challenge-06-solution.md   # Full debug walkthrough
│
└── scripts/
    ├── setup-aws-cli.sh     # AWS CLI installation (Ubuntu/Debian)
    ├── setup-terraform.sh   # Terraform installation (Ubuntu/Debian)
    ├── validate.sh          # Pre-flight environment checker
    └── destroy.sh           # Safe infrastructure teardown
```

## Key Concepts

### Declarative Infrastructure
Terraform is **declarative**: you describe *what* you want, not *how* to build it. Terraform figures out the order, dependencies, and execution plan automatically.

```hcl
resource "aws_vpc" "main" {    # Creates infrastructure
  cidr_block = "10.0.0.0/16"
}

data "aws_ami" "ubuntu" {      # Queries existing information
  most_recent = true
  owners      = ["099720109477"]
}
```

### The Attach Pattern

Most Game Day issues involve **resources that exist but aren't connected**:

| Symptom | Missing Attachment |
|---------|--------------------|
| Can't reach instances | Route table not associated with subnets |
| Requests time out silently | Security group missing egress rule |
| ALB returns 503 | ASG not attached to target group |
| Instances unhealthy | Launch template missing security group |
| 504 Gateway Timeout | ALB set to internal or listener on wrong port |

### Debugging Sequence

When something doesn't work, check in this order:

1. **Routing** -- Is there a path from the internet to the VPC?
2. **Security** -- Are the right ports open in both directions?
3. **Compute** -- Are instances running with the right config?
4. **Load Balancing** -- Is the ALB connected to healthy targets?

See [docs/cheat-sheet.md](docs/cheat-sheet.md) for a printable quick-reference.

## Game Day Tips

1. **Check attachments first** -- 90% of issues are unattached resources
2. **Don't forget egress rules** -- ingress without egress = silent failure
3. **Use `terraform plan`** before `terraform apply` to preview changes
4. **Read error messages carefully** -- Terraform tells you exactly what's wrong
5. **Tag everything** for easy identification in the AWS Console
6. **Work as a team** -- divide and conquer: one person on networking, one on compute
7. **Use AI tools when stuck** -- you're allowed and encouraged to
8. **Stay calm** -- it's applied troubleshooting, not an exam

## Documentation

| Document | Description |
|----------|-------------|
| [Setup Guide](docs/setup-guide.md) | AWS account, CLI, Terraform, and VS Code setup |
| [AWS Concepts](docs/aws-concepts.md) | VPC, subnets, security groups, ALB, ASG explained |
| [Terraform Guide](docs/terraform-guide.md) | Commands, block types, references, loops |
| [Troubleshooting](docs/troubleshooting.md) | The attach pattern, common errors, debug commands |
| [Game Day Prep](docs/gameday-prep.md) | Event details, study plan, bookmarks |
| [Cheat Sheet](docs/cheat-sheet.md) | Printable quick-reference for commands and checks |

## Game Day Results -- March 13, 2026

Successfully competed in the **AWS GameDay with Terraform** hosted by Illinois Tech's College of Computing. Completed all quests and applied real-world Terraform troubleshooting under time pressure.

### Intro to Terraform with HashiCorp (HashiCafe Quest)

| Task | Challenge | Resolution | Points |
|------|-----------|------------|--------|
| 1 | Configure remote state with S3 | Added S3 backend block to `terraform.tf`, ran `terraform init` to migrate state, deployed 41 resources including CloudFront, API Gateway, Lambda, DynamoDB, and S3 | 25,000 |
| 2 | Fix S3 bucket policy misconfiguration | Identified that the bucket policy granted `s3:ListBucket` instead of `s3:GetObject`, preventing CloudFront from serving static files. Fixed the IAM action and redeployed | 25,000 |
| 3 | Restore infrastructure after crash | Detected via `terraform plan` that API Gateway resources were deleted outside of Terraform. Ran `terraform apply` to reconcile drift and restore the full deployment | 25,000+ |
| 4 | Terraform knowledge questions | Answered correctly: `terraform fmt` is the standard formatting method | Bonus |

**Final Score (HashiCafe): 120,755 points**

### Architecture Deployed

```
CloudFront CDN ──> S3 Static Website (index.html, CSS, images)
                        │
                        ├── API Gateway (REST) ──> Lambda (barista) ──> DynamoDB (coffee menu)
                        │
                        └── Lambda (supplier) ──> DynamoDB (seeds coffee data)
```

**AWS Services Used:** S3, CloudFront, API Gateway, Lambda, DynamoDB, IAM, CloudWatch

### Key Takeaways

- **Remote state is essential** for team collaboration -- always use an S3 backend with Terraform
- **Terraform detects infrastructure drift** -- if someone manually deletes AWS resources, `terraform plan` catches it and `terraform apply` restores desired state
- **IAM policy actions matter** -- `s3:ListBucket` vs `s3:GetObject` is the difference between a working site and "Access Denied"
- **CloudFront deployments take time** -- expect 3-5 minutes for CDN distribution creation

---

## References

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Language Reference](https://developer.hashicorp.com/terraform/language)
- [AWS VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [Course Reference (ITMT-430)](https://github.com/illinoistech-itm/jhajek/tree/master/itmt-430)

## Author

**Freddrick Logan** -- Illinois Institute of Technology, ITMT-430
- [GitHub](https://github.com/Freddricklogan)
- [Portfolio](https://github.com/Freddricklogan/freddricklogan)
