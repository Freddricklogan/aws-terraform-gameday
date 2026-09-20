# =============================================================================
# Root composition smoke test.
#
# Proves the four modules wire together and that a plan of the whole stack
# succeeds with the shipped defaults -- entirely against mocked providers.
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

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    }
  }
}

run "defaults_produce_a_valid_plan" {
  command = plan

  assert {
    condition     = startswith(output.application_url, "http")
    error_message = "The stack must expose an application URL."
  }

  assert {
    condition     = length(output.private_subnet_ids) == 3
    error_message = "The default az_count of 3 must yield three private subnets."
  }

  assert {
    condition     = length(output.public_subnet_ids) == 3
    error_message = "The default az_count of 3 must yield three public subnets."
  }
}

run "two_az_lab_profile_still_plans" {
  command = plan

  variables {
    environment      = "lab"
    az_count         = 2
    min_size         = 1
    max_size         = 2
    desired_capacity = 1
  }

  assert {
    condition     = length(output.private_subnet_ids) == 2
    error_message = "az_count = 2 must yield two private subnets."
  }
}

run "https_profile_plans_with_a_certificate" {
  command = plan

  variables {
    certificate_arn = "arn:aws:acm:us-east-2:000000000000:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = startswith(output.application_url, "https://")
    error_message = "Supplying a certificate must switch the advertised URL to https."
  }
}
