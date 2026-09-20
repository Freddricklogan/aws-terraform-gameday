# =============================================================================
# Provider configuration.
#
# Credentials are NEVER written here. The provider resolves them from the
# standard chain: GitHub OIDC -> assumed role in CI, or SSO / named profile
# locally. There is no shared_credentials_files pointing at a long-lived key.
#
# default_tags applies the tagging strategy to every taggable resource in the
# root module and in all child modules, so no module has to remember to do it.
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
