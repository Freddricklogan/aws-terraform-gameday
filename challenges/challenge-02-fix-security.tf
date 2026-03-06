# =============================================================================
# CHALLENGE 2: Fix the Security Group
#
# SCENARIO: Web server is running, route table is correct, internet gateway
# is attached, but HTTP requests time out. SSH also doesn't work.
#
# HINT: The security group has issues. There are 2 bugs.
# =============================================================================

resource "aws_security_group" "challenge2" {
  name        = "challenge-02-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.challenge1.id  # Assumes challenge 1 VPC exists
  tags        = { Name = "challenge-02" }
}

# SSH ingress rule -- this is correct
resource "aws_vpc_security_group_ingress_rule" "challenge2_ssh" {
  security_group_id = aws_security_group.challenge2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# ============================================================
# BUG 1: HTTP ingress rule is on wrong port.
#         Port 443 is HTTPS, but our server only runs HTTP on port 80.
#
# FIX: Change from_port and to_port from 443 to 80
# ============================================================
resource "aws_vpc_security_group_ingress_rule" "challenge2_http" {
  security_group_id = aws_security_group.challenge2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443  # BUG: Should be 80
  ip_protocol       = "tcp"
  to_port           = 443  # BUG: Should be 80
}

# ============================================================
# BUG 2: There is NO egress rule at all.
#         Traffic comes IN but responses can never go OUT.
#         This is the classic "silent failure" -- no error messages,
#         the request just times out.
#
# FIX: Add this egress rule:
# resource "aws_vpc_security_group_egress_rule" "challenge2_all" {
#   security_group_id = aws_security_group.challenge2.id
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "-1"
# }
# ============================================================
