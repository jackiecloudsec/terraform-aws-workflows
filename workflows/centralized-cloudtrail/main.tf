###############################################################################
# Centralized CloudTrail → S3 + CloudWatch Logs + SNS Alerts
#
# Org-wide or multi-account CloudTrail that delivers to a central S3 bucket,
# streams to CloudWatch Logs for real-time metric filters, and alerts on
# high-risk API calls via SNS.
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  tags = merge(var.tags, {
    Workflow = "centralized-cloudtrail"
  })
}

# ---------------------------------------------------------------------------
# S3 — trail destination
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "trail_bucket_policy" {
  statement {
    sid     = "AWSCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}/AWSLogs/${local.account_id}/*",
      var.organization_id != null ? "arn:aws:s3:::${var.s3_bucket_name}/AWSLogs/${var.organization_id}/*" : "arn:aws:s3:::${var.s3_bucket_name}/AWSLogs/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

module "trail_bucket" {
  source        = "../../modules/s3-bucket"
  bucket_name   = var.s3_bucket_name
  versioning    = true
  kms_key_arn   = var.kms_key_arn
  bucket_policy = data.aws_iam_policy_document.trail_bucket_policy.json
  tags          = local.tags
}

# ---------------------------------------------------------------------------
# CloudWatch Logs — real-time streaming
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${var.prefix}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

data "aws_iam_policy_document" "cloudtrail_cw_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.trail.arn}:*"]
  }
}

module "cloudtrail_cw_role" {
  source = "../../modules/iam-role"
  name   = "${var.prefix}-cloudtrail-to-cw"
  assume_role_principals = [{
    type        = "Service"
    identifiers = ["cloudtrail.amazonaws.com"]
  }]
  inline_policy = data.aws_iam_policy_document.cloudtrail_cw_policy.json
  tags          = local.tags
}

# ---------------------------------------------------------------------------
# CloudTrail
# ---------------------------------------------------------------------------
resource "aws_cloudtrail" "this" {
  name                       = "${var.prefix}-trail"
  s3_bucket_name             = module.trail_bucket.bucket
  is_multi_region_trail      = var.multi_region
  is_organization_trail      = var.organization_id != null
  include_global_service_events = true
  enable_log_file_validation = true
  kms_key_id                 = var.kms_key_arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn  = module.cloudtrail_cw_role.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# SNS — security alerts
# ---------------------------------------------------------------------------
module "alert_topic" {
  source          = "../../modules/sns-topic"
  name            = "${var.prefix}-cloudtrail-alerts"
  email_endpoints = var.alert_emails
  tags            = local.tags
}

# ---------------------------------------------------------------------------
# CloudWatch metric filters + alarms for high-risk API calls
# ---------------------------------------------------------------------------
locals {
  metric_filters = {
    unauthorized-api = {
      pattern     = "{ ($.errorCode = \"*UnauthorizedAccess\") || ($.errorCode = \"AccessDenied*\") }"
      description = "Unauthorized API calls"
    }
    console-signin-failure = {
      pattern     = "{ ($.eventName = \"ConsoleLogin\") && ($.errorMessage = \"Failed authentication\") }"
      description = "Failed console sign-in attempts"
    }
    root-usage = {
      pattern     = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
      description = "Root account usage"
    }
    iam-changes = {
      pattern     = "{ ($.eventName=CreateUser) || ($.eventName=DeleteUser) || ($.eventName=CreateRole) || ($.eventName=DeleteRole) || ($.eventName=AttachRolePolicy) || ($.eventName=DetachRolePolicy) || ($.eventName=AttachUserPolicy) || ($.eventName=PutUserPolicy) }"
      description = "IAM policy changes"
    }
    nacl-changes = {
      pattern     = "{ ($.eventName=CreateNetworkAcl) || ($.eventName=CreateNetworkAclEntry) || ($.eventName=DeleteNetworkAcl) || ($.eventName=DeleteNetworkAclEntry) || ($.eventName=ReplaceNetworkAclEntry) || ($.eventName=ReplaceNetworkAclAssociation) }"
      description = "Network ACL changes"
    }
    security-group-changes = {
      pattern     = "{ ($.eventName=AuthorizeSecurityGroupIngress) || ($.eventName=AuthorizeSecurityGroupEgress) || ($.eventName=RevokeSecurityGroupIngress) || ($.eventName=RevokeSecurityGroupEgress) || ($.eventName=CreateSecurityGroup) || ($.eventName=DeleteSecurityGroup) }"
      description = "Security group changes"
    }
    cloudtrail-changes = {
      pattern     = "{ ($.eventName=StopLogging) || ($.eventName=DeleteTrail) || ($.eventName=UpdateTrail) }"
      description = "CloudTrail config changes (defense evasion)"
    }
    s3-policy-changes = {
      pattern     = "{ ($.eventName=PutBucketPolicy) || ($.eventName=PutBucketAcl) || ($.eventName=DeleteBucketPolicy) || ($.eventName=PutBucketPublicAccessBlock) }"
      description = "S3 bucket policy changes"
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each       = local.metric_filters
  name           = "${var.prefix}-${each.key}"
  log_group_name = aws_cloudwatch_log_group.trail.name
  pattern        = each.value.pattern

  metric_transformation {
    name      = "${var.prefix}-${each.key}"
    namespace = "${var.prefix}/CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each            = local.metric_filters
  alarm_name          = "${var.prefix}-${each.key}"
  alarm_description   = each.value.description
  namespace           = "${var.prefix}/CloudTrailMetrics"
  metric_name         = "${var.prefix}-${each.key}"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.alert_topic.arn]
  tags                = local.tags
}
