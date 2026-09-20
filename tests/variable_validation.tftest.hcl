# =============================================================================
# Variable validation tests.
#
# Run with:  terraform test          (or: make test)
#
# These runs never call AWS. `mock_provider` supplies synthetic values for
# every provider read, so the whole file executes offline and for free -- which
# is what makes it usable as a pre-commit-speed guard rail.
#
# Each run asserts that a *bad* value is rejected. A validation block that
# never fires is indistinguishable from no validation at all, so the tests
# prove the guard rails actually guard.
# =============================================================================

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-2a", "us-east-2b", "us-east-2c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "000000000000"
      arn        = "arn:aws:iam::000000000000:role/mock"
      user_id    = "AIDAMOCK"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-east-2"
    }
  }

  mock_data "aws_elb_service_account" {
    defaults = {
      arn = "arn:aws:iam::000000000000:root"
      id  = "000000000000"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-00000000000000000"
    }
  }
}

# --- Region ------------------------------------------------------------------

run "rejects_malformed_region" {
  command = plan

  variables {
    aws_region = "us-east"
  }

  expect_failures = [var.aws_region]
}

# --- Naming ------------------------------------------------------------------

run "rejects_uppercase_project_slug" {
  command = plan

  variables {
    project = "GameDay"
  }

  expect_failures = [var.project]
}

run "rejects_project_slug_with_trailing_hyphen" {
  command = plan

  variables {
    project = "gameday-"
  }

  expect_failures = [var.project]
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}

# --- Tagging strategy --------------------------------------------------------

run "rejects_empty_owner" {
  command = plan

  variables {
    owner = "   "
  }

  expect_failures = [var.owner]
}

run "rejects_unknown_data_classification" {
  command = plan

  variables {
    data_classification = "top-secret"
  }

  expect_failures = [var.data_classification]
}

run "rejects_additional_tags_that_shadow_reserved_keys" {
  command = plan

  variables {
    additional_tags = {
      Environment = "somewhere-else"
    }
  }

  expect_failures = [var.additional_tags]
}

# --- Network -----------------------------------------------------------------

run "rejects_invalid_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/33"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_single_availability_zone" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}

run "rejects_invalid_alb_ingress_cidr" {
  command = plan

  variables {
    alb_ingress_cidrs = ["not-a-cidr"]
  }

  expect_failures = [var.alb_ingress_cidrs]
}

# --- Capacity ----------------------------------------------------------------

run "rejects_desired_capacity_above_max_size" {
  command = plan

  variables {
    min_size         = 2
    max_size         = 4
    desired_capacity = 9
  }

  expect_failures = [var.desired_capacity]
}

run "rejects_desired_capacity_below_min_size" {
  command = plan

  variables {
    min_size         = 3
    max_size         = 6
    desired_capacity = 1
  }

  expect_failures = [var.desired_capacity]
}

run "rejects_runaway_max_size" {
  command = plan

  variables {
    max_size = 500
  }

  expect_failures = [var.max_size]
}

# --- Identifiers -------------------------------------------------------------

run "rejects_certificate_arn_that_is_not_acm" {
  command = plan

  variables {
    certificate_arn = "arn:aws:iam::000000000000:server-certificate/legacy"
  }

  expect_failures = [var.certificate_arn]
}

run "rejects_malformed_alarm_email" {
  command = plan

  variables {
    alarm_email = "not-an-email"
  }

  expect_failures = [var.alarm_email]
}

run "rejects_short_log_retention" {
  command = plan

  variables {
    log_retention_days = 7
  }

  expect_failures = [var.log_retention_days]
}
