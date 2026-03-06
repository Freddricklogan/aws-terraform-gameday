# AWS Terraform Infrastructure -- Game Day Preparation

## Three-Tier Web Application on AWS with Terraform

This repository contains Terraform Infrastructure as Code (IaC) for deploying a complete three-tier web application on AWS. Built in preparation for the **AWS & IBM Terraform Game Day** (March 13, 2026) at Illinois Institute of Technology.

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
- AWS CLI installed and configured
- Terraform installed (v1.5+)
- VS Code with HashiCorp HCL and Terraform autocomplete extensions
- Linux environment (Ubuntu VM via Parallels, VirtualBox, or WSL)

## Quick Start

```bash
# 1. Clone this repository
git clone https://github.com/Freddricklogan/aws-terraform-gameday.git
cd aws-terraform-gameday

# 2. Configure AWS credentials
aws configure
# Enter: Access Key, Secret Key, Region (us-east-2), Output format (json)

# 3. Initialize Terraform (downloads AWS provider libraries)
terraform init

# 4. Validate syntax
terraform validate

# 5. Preview what will be created
terraform plan

# 6. Deploy infrastructure
terraform apply
# Type 'yes' when prompted (~2-3 minutes to complete)

# 7. Access your application
# The load balancer DNS will be output after apply completes
# Visit: http://<load-balancer-dns>

# 8. IMPORTANT: Destroy when done (avoid charges)
terraform destroy
# Type 'yes' when prompted
```

## Project Structure

```
aws-terraform-gameday/
├── main.tf                 # Core infrastructure (VPC, subnets, ASG, ALB)
├── provider.tf             # AWS provider configuration
├── variables.tf            # Variable definitions
├── terraform.tfvars        # Variable values (region, instance type, tags)
├── outputs.tf              # Output values (load balancer URL, VPC ID, etc.)
├── install-env.sh          # EC2 bootstrap script (installs nginx)
├── docs/
│   ├── setup-guide.md      # Detailed environment setup instructions
│   ├── aws-concepts.md     # Key AWS concepts for Game Day
│   ├── terraform-guide.md  # Terraform syntax and commands reference
│   ├── troubleshooting.md  # Common issues and debugging techniques
│   └── gameday-prep.md     # Game Day strategy and tips
├── challenges/
│   ├── challenge-01-fix-routing.tf      # Practice: broken route table
│   ├── challenge-02-fix-security.tf     # Practice: misconfigured security group
│   └── challenge-03-fix-autoscaling.tf  # Practice: broken ASG attachment
└── scripts/
    ├── setup-aws-cli.sh    # AWS CLI installation script
    └── setup-terraform.sh  # Terraform installation script
```

## Key Concepts

### Declarative vs Functional
Terraform is **declarative**: you describe *what* you want, not *how* to build it. Terraform figures out the order, dependencies, and execution plan automatically.

### Resource Blocks
```hcl
resource "aws_vpc" "main" {    # Creates infrastructure
  cidr_block = "10.0.0.0/16"
}
```

### Data Blocks
```hcl
data "aws_ami" "ubuntu" {      # Queries existing information
  most_recent = true
  owners      = ["099720109477"]
}
```

### The Attach Pattern
Most Game Day issues involve **forgetting to attach resources**:
- Route table exists but not associated with subnets
- Security group exists but not attached to instances
- Load balancer exists but not connected to target group
- Egress rule missing (traffic goes in, never comes back)

## Game Day Tips

1. **Bookmark the Terraform AWS Provider docs**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
2. **Check attachments first** -- 90% of issues are unattached resources
3. **Don't forget egress rules** -- ingress without egress = silent failure
4. **Use `terraform plan`** before `terraform apply` to preview changes
5. **Tag everything** for easy identification
6. **Read error messages carefully** -- Terraform tells you exactly what's wrong

## References

- [AWS CLI Getting Started](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Language Reference](https://developer.hashicorp.com/terraform/language/providers)
- [Course Reference Code (itmo-463)](https://github.com/illinoistech-itm/jhajek/tree/master/itmt-430)

## Author

**Freddrick Logan** -- Illinois Institute of Technology
- [GitHub](https://github.com/Freddricklogan)
- [Portfolio](https://github.com/Freddricklogan/freddricklogan)
