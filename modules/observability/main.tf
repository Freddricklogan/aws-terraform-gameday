# =============================================================================
# Observability module -- the evidence tier.
#
# Creates the sinks that the rest of the stack writes to:
#   * S3 bucket for ALB access logs (encrypted, versioned, private, expiring)
#   * CloudWatch log group + IAM role for VPC flow logs
#   * SNS topic the ALB alarms publish to
#
# Nothing in here is optional in a reviewed environment: without it there is
# no answer to "who reached the ALB at 02:14 and what did it return?".
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# The ELB account that writes access logs differs by region generation.
# Regions launched before August 2022 use a per-region AWS account; newer
# regions use the logdelivery service principal. Both are granted below.
data "aws_elb_service_account" "this" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "${var.name_prefix}-access-logs-${local.account_id}-${data.aws_region.current.name}"
}

# -----------------------------------------------------------------------------
# ALB access log bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "access_logs" {
  # checkov:skip=CKV_AWS_18:This IS the log bucket; enabling S3 access logging on it would create a self-referential log loop. Object-level activity is covered by CloudTrail data events at the account level.
  # checkov:skip=CKV_AWS_144:Single-region training environment; cross-region replication is out of scope and adds cost.
  # checkov:skip=CKV_AWS_145:ALB access log delivery supports SSE-S3 (AES256) only; a customer-managed KMS key makes the delivery fail. SSE-S3 is applied below.
  # checkov:skip=CKV2_AWS_62:Event notifications on a log bucket would create noise, not signal; log arrival is monitored through the ALB metrics instead.
  bucket        = local.bucket_name
  force_destroy = true # Game Day environments are torn down daily; see ADR-3.

  tags = {
    Name        = "${var.name_prefix}-access-logs"
    DataClass   = "operational-logs"
    Description = "ALB access logs"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  # checkov:skip=CKV_AWS_145:ALB access log delivery supports SSE-S3 (AES256) only; a customer-managed KMS key causes the delivery to fail silently.
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  depends_on = [aws_s3_bucket_versioning.access_logs]

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.access_log_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "access_logs" {
  # Regions launched before Aug 2022: named ELB account principal.
  statement {
    sid    = "AllowELBAccountPutObject"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.this.arn]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_logs.arn}/alb/AWSLogs/${local.account_id}/*"]
  }

  # Regions launched after Aug 2022: log delivery service principal.
  statement {
    sid    = "AllowLogDeliveryServicePutObject"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_logs.arn}/alb/AWSLogs/${local.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "AllowLogDeliveryAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.access_logs.arn]
  }

  # Belt and braces: reject anything that is not TLS.
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.access_logs.arn,
      "${aws_s3_bucket.access_logs.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs.json

  depends_on = [aws_s3_bucket_public_access_block.access_logs]
}

# -----------------------------------------------------------------------------
# VPC flow logs sink
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "flow_logs" {
  # checkov:skip=CKV_AWS_158:Flow logs are encrypted with the CloudWatch Logs service key; a customer-managed KMS key is tracked as follow-up work and is not free-tier friendly.
  # checkov:skip=CKV_AWS_338:A 1-year retention floor is a production control. This training stack defaults to var.log_retention_days = 90 and the variable rejects anything under 30; raise it to 365 for a regulated environment.
  name              = "/aws/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.name_prefix}-flow-logs"
  }
}

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name_prefix}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json

  tags = {
    Name = "${var.name_prefix}-flow-logs"
  }
}

data "aws_iam_policy_document" "flow_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    # Scoped to this log group only -- no wildcard on logs:*.
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.name_prefix}-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}

# -----------------------------------------------------------------------------
# Alarm topic
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alarms" {
  name              = "${var.name_prefix}-alarms"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name = "${var.name_prefix}-alarms"
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
