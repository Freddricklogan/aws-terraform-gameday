# AWS Core Concepts for Game Day

## Regions and Availability Zones

**Region**: A geographic area with multiple data centers (e.g., us-east-2 = Ohio).

**Availability Zone (AZ)**: A cluster of 3-5 data centers within a region. Named as region + letter (e.g., us-east-2a, us-east-2b, us-east-2c).

Deploying across multiple AZs provides fault tolerance -- if one AZ has issues, traffic fails over to another.

## VPC (Virtual Private Cloud)

Your own isolated network within AWS. You control:
- IP address range (CIDR block)
- Subnets
- Route tables
- Internet gateways
- Security groups

The default VPC Amazon provides is useful for quick tests, but production workloads should use a custom VPC for full control.

**CIDR Quick Math:**
- `/16` = 65,536 IPs (10.0.0.0/16 -- the VPC)
- `/24` = 256 IPs (10.0.0.0/24 -- a subnet)
- Formula: 2^(32 - prefix) = number of IPs

## Subnets

A subdivision of your VPC. Each subnet lives in exactly one AZ.

- **Public subnet**: Has a route to an Internet Gateway (instances can reach the internet)
- **Private subnet**: No direct internet access (used for databases, internal services)

Subnets cannot overlap CIDR ranges:
- Subnet A: 10.0.0.0/24 (10.0.0.0 - 10.0.0.255)
- Subnet B: 10.0.16.0/24 (10.0.16.0 - 10.0.16.255)
- Subnet C: 10.0.32.0/24 (10.0.32.0 - 10.0.32.255)

## Internet Gateway

Connects your VPC to the public internet. Without it, nothing in your VPC can communicate externally.

You create it and attach it to your VPC, then add a route in your route table pointing 0.0.0.0/0 to the gateway.

## Route Tables

Define where network traffic goes. Every subnet needs a route table association.

Key routes:
- `0.0.0.0/0 -> Internet Gateway` = default route (anything not local goes to the internet)
- `10.0.0.0/16 -> local` = local traffic stays within the VPC

**Common Game Day issue**: Route table created but not associated as the main route table, so the default (locked-down) route table is used instead.

## Security Groups

Virtual firewall for your instances. Rules are stateful (if you allow inbound, the response is automatically allowed outbound).

- **Ingress (inbound)**: What traffic can reach your instances
- **Egress (outbound)**: What traffic can leave your instances
- **Default**: All inbound blocked, all outbound blocked

**Critical**: If you open ingress port 80 but forget the egress rule, HTTP requests arrive at your server, the server processes them, but responses never make it back to the client. This is an extremely common and hard-to-debug issue.

## EC2 (Elastic Compute Cloud)

Virtual machines (instances) in AWS.

- **AMI (Amazon Machine Image)**: Blueprint for an instance (OS, pre-installed software)
- **Instance Type**: Hardware configuration (CPU, memory). `t3.micro` is free tier.
- **Key Pair**: SSH credentials. You create a pair, give the public key to AWS, keep the private key.

## Auto Scaling Group (ASG)

Automatically manages a fleet of EC2 instances:
- **Desired capacity**: How many instances you want running
- **Min size**: Never scale below this number
- **Max size**: Never scale above this number
- **Health checks**: If an instance fails, ASG terminates it and launches a replacement

ASG is **declarative**: you say "I want 3 instances" and ASG makes it happen, including replacing failed ones.

## Application Load Balancer (ALB)

Distributes incoming HTTP/HTTPS traffic across multiple instances.

Components:
- **Load Balancer**: The public-facing entry point
- **Listener**: Defines what port/protocol to accept (e.g., HTTP on port 80)
- **Target Group**: The pool of instances that receive traffic
- **Health Check**: How the ALB determines if an instance is healthy

## Launch Template

A reusable configuration for EC2 instances:
- Which AMI to use
- Instance type
- Security groups
- User data (bootstrap script)
- Key pair

The Auto Scaling Group references the launch template to know what kind of instance to create.

## The Full Flow

```
User Request → Load Balancer → Listener → Target Group → Healthy Instance
                                                              ↑
                                              Auto Scaling Group
                                              (manages lifecycle)
                                                              ↑
                                              Launch Template
                                              (defines instance config)
```
