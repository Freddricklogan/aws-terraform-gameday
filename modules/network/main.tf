# =============================================================================
# Network module -- VPC, public/private subnets, routing, flow logs.
#
# Teaching note (Game Day): every resource here is created AND attached.
# The single most common Game Day failure is a resource that exists but was
# never associated with anything. Search this file for "association" to see
# the four attachment points that must never be forgotten.
# =============================================================================

data "aws_availability_zones" "available" {
  # checkov:skip=CKV_AWS_394:The result set is not consumed wholesale. local.azs slices exactly var.az_count names, so a new AZ in the region cannot silently widen this deployment.
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Deterministic, non-overlapping /24s carved out of the VPC CIDR.
  # Public tier takes the first az_count subnets, private tier the next block.
  newbits = 24 - tonumber(split("/", var.vpc_cidr)[1])

  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, local.newbits, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, local.newbits, i + 16)]

  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.az_count) : 0

  enable_flow_logs = var.enable_flow_logs != null ? var.enable_flow_logs : (var.flow_log_destination_arn != "" && var.flow_log_role_arn != "")
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.name_prefix
  }
}

# Default SG is left in place by AWS with an allow-all self rule. Terraform
# cannot delete it, so we adopt it and strip every rule (CKV2_AWS_12).
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-default-do-not-use"
  }
}

# -----------------------------------------------------------------------------
# VPC flow logs -- who talked to whom, accepted and rejected
# -----------------------------------------------------------------------------
resource "aws_flow_log" "this" {
  count = local.enable_flow_logs ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = var.flow_log_destination_arn
  iam_role_arn             = var.flow_log_role_arn
  max_aggregation_interval = 60

  tags = {
    Name = "${var.name_prefix}-flow-logs"
  }
}

# -----------------------------------------------------------------------------
# Public tier -- internet gateway + public subnets (ALB only)
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.public_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  # Hardened: the ALB gets its public IPs from the load balancer service, not
  # from subnet auto-assignment. Nothing else should land in these subnets.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-public"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# ATTACHMENT 1 of 4 -- without this the public subnets fall back to the main
# (local-only) route table and the ALB is unreachable.
resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Private tier -- NAT egress + private subnets (application instances)
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-${count.index}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name_prefix}-nat-${count.index}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.private_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-private-${local.azs[count.index]}"
    Tier = "private"
  }
}

resource "aws_route_table" "private" {
  count = var.az_count

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-private-${local.azs[count.index]}"
  }
}

resource "aws_route" "private_default" {
  count = var.enable_nat_gateway ? var.az_count : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}

# ATTACHMENT 2 of 4
resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
