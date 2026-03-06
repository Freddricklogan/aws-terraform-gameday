# =============================================================================
# CHALLENGE 4: Fix the Launch Template
#
# SCENARIO: Auto Scaling Group is running, load balancer is healthy, but
# instances show a blank page instead of the nginx welcome page.
# Also, instances are launching in the default VPC security group
# instead of the custom one.
#
# HINT: The launch template has 2 configuration issues.
# =============================================================================

# Assume these exist from the working infrastructure
# - aws_security_group.web (custom security group)
# - data.aws_ami.ubuntu (Ubuntu AMI)

resource "aws_launch_template" "challenge4" {
  name          = "challenge-04-lt"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # ============================================================
  # BUG 1: user_data is missing entirely.
  #         Without user_data, the instance boots as a plain Ubuntu
  #         server with no nginx installed. The ALB health check
  #         hits port 80, gets no response, marks it unhealthy.
  #
  # FIX: Add this line:
  # user_data = filebase64("${path.module}/install-env.sh")
  # ============================================================

  # ============================================================
  # BUG 2: vpc_security_group_ids is missing.
  #         Without specifying a security group, the instance uses
  #         the VPC's default security group, which blocks all
  #         inbound traffic. SSH and HTTP won't work.
  #
  # FIX: Add this line:
  # vpc_security_group_ids = [aws_security_group.web.id]
  # ============================================================

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "challenge-04"
    }
  }
}
