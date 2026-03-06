# =============================================================================
# Data Sources
# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
# =============================================================================

# Get the latest Ubuntu AMI from Canonical
# Data block: queries existing information, does not create resources
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  # Canonical's AWS account ID
  owners = ["099720109477"]
}

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# VPC -- Virtual Private Cloud
# This is the networking foundation. Everything lives inside the VPC.
# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.project_tag
  }
}

# =============================================================================
# Subnets -- Subdivisions of the VPC network
# One subnet per availability zone for high availability
# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
# =============================================================================

resource "aws_subnet" "public" {
  count = length(var.subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_tag}-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# =============================================================================
# Internet Gateway -- Connects VPC to the public internet
# Without this, no traffic can leave or enter the VPC
# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
# =============================================================================

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.project_tag
  }
}

# =============================================================================
# Route Table -- Defines how network traffic is directed
# Critical: forgetting to attach this is the #1 Game Day issue
# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
# =============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Default route: send all traffic to the internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = var.project_tag
  }
}

# CRITICAL: Associate route table as the main route table for the VPC
# Without this, the VPC uses the default (locked-down) route table
resource "aws_main_route_table_association" "main" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.public.id
}

# Associate route table with each subnet
resource "aws_route_table_association" "public" {
  count = length(var.subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# Security Group -- Firewall rules for instances
# By default, ALL ports are blocked. You must explicitly open them.
# IMPORTANT: Don't forget EGRESS. Ingress without egress = silent failure.
# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
# =============================================================================

resource "aws_security_group" "web" {
  name        = "${var.project_tag}-sg"
  description = "Allow SSH and HTTP inbound, all outbound"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = var.project_tag
  }
}

# Ingress: Allow SSH (port 22) from anywhere
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# Ingress: Allow HTTP (port 80) from anywhere
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# Egress: Allow ALL outbound traffic
# Without this rule, responses never leave the instance
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# =============================================================================
# Launch Template -- Blueprint for EC2 instances
# Defines what each instance looks like. ASG uses this to spin up instances.
# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
# =============================================================================

resource "aws_launch_template" "web" {
  name          = "${var.project_tag}-lt"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # Bootstrap script: runs on first boot to install nginx
  user_data = filebase64("${path.module}/install-env.sh")

  # Attach the security group (firewall)
  vpc_security_group_ids = [aws_security_group.web.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.project_tag
    }
  }
}

# =============================================================================
# Auto Scaling Group -- Manages instance lifecycle automatically
# Declarative: tell it desired state, it makes it happen
# If an instance dies, ASG launches a replacement automatically
# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
# =============================================================================

resource "aws_autoscaling_group" "web" {
  name = "${var.project_tag}-asg"

  # Spread instances across all subnets (all AZs) for high availability
  vpc_zone_identifier = aws_subnet.public[*].id

  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_grace_period = 300
  health_check_type         = "ELB"

  # Use the launch template to create instances
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.project_tag
    propagate_at_launch = true
  }
}

# =============================================================================
# Application Load Balancer -- Distributes traffic across instances
# This is the single public-facing entry point to the application
# Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
# =============================================================================

resource "aws_lb" "web" {
  name               = "${var.project_tag}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = var.project_tag
  }
}

# Target Group -- Where instances register for health checks
resource "aws_lb_target_group" "web" {
  name     = "${var.project_tag}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = var.project_tag
  }
}

# Listener -- Tells the load balancer what traffic to accept
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Attach ASG to the load balancer target group
resource "aws_autoscaling_attachment" "web" {
  autoscaling_group_name = aws_autoscaling_group.web.id
  lb_target_group_arn    = aws_lb_target_group.web.arn
}
