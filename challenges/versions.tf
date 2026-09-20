# =============================================================================
# Version constraints for the challenge exercises.
#
# `tflint --recursive` treats this directory as its own module root, so it needs
# its own terraform block -- without it, terraform_required_version and
# terraform_required_providers both fire. The constraints mirror the root
# configuration so that a facilitator running a challenge in isolation resolves
# the same provider line as the main stack.
#
# The deliberate defects in the challenge-*.tf files are unaffected by this file.
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
