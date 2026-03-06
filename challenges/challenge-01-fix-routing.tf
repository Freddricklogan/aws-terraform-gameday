# =============================================================================
# CHALLENGE 1: Fix the Routing
#
# SCENARIO: Infrastructure deployed but instances cannot reach the internet.
# Web servers are running but no one can access them externally.
#
# HINT: The route table exists but something is missing...
# Find and fix the 2 issues below.
# =============================================================================

# This VPC is correct
resource "aws_vpc" "challenge1" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "challenge-01" }
}

# This subnet is correct
resource "aws_subnet" "challenge1" {
  vpc_id                  = aws_vpc.challenge1.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
  tags = { Name = "challenge-01" }
}

# This gateway is correct
resource "aws_internet_gateway" "challenge1" {
  vpc_id = aws_vpc.challenge1.id
  tags   = { Name = "challenge-01" }
}

# This route table is correct
resource "aws_route_table" "challenge1" {
  vpc_id = aws_vpc.challenge1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.challenge1.id
  }
  tags = { Name = "challenge-01" }
}

# ============================================================
# BUG 1: The route table is never set as the main route table.
#         The VPC is using the default (locked-down) route table.
#
# FIX: Uncomment this block:
# resource "aws_main_route_table_association" "challenge1" {
#   vpc_id         = aws_vpc.challenge1.id
#   route_table_id = aws_route_table.challenge1.id
# }
# ============================================================

# ============================================================
# BUG 2: The subnet is never associated with the route table.
#         Even with the main route table set, explicit subnet
#         association ensures traffic is routed correctly.
#
# FIX: Uncomment this block:
# resource "aws_route_table_association" "challenge1" {
#   subnet_id      = aws_subnet.challenge1.id
#   route_table_id = aws_route_table.challenge1.id
# }
# ============================================================
