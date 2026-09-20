# =============================================================================
# Version constraints.
#
# terraform >= 1.9 is required for cross-variable `validation` blocks and for
# the `terraform test` mock_provider features used in tests/.
#
# The AWS provider is pinned to the 5.x line with a pessimistic constraint.
# .terraform.lock.hcl is committed so that CI and every facilitator resolve the
# identical provider build and checksum -- see ADR-1 in the README.
# =============================================================================

terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
