###############################################################################
# GuardDuty → EventBridge → SNS/Lambda Alerting
#
# Enables GuardDuty, routes findings through EventBridge, and sends
# alerts to SNS (email) and optionally a Lambda for Slack/webhook.
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
    Workflow = "guardduty-alerting"
  })
}

# ---------------------------------------------------------------------------
# GuardDuty
# ---------------------------------------------------------------------------
resource "aws_guardduty_detector" "this" {
  enable = true

  datasources {
    s3_logs {
      enable = var.enable_s3_protection
    }
    kubernetes {
      audit_logs {
        enable = var.enable_eks_protection
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.enable_malware_protection
        }
      }
    }
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# SNS — alert topic
# ---------------------------------------------------------------------------
module "alert_topic" {
  source          = "../../modules/sns-topic"
  name            = "${var.prefix}-guardduty-alerts"
  email_endpoints = var.alert_emails
  tags            = local.tags
}

# Allow EventBridge to publish to SNS
data "aws_iam_policy_document" "sns_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [module.alert_topic.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alert" {
  arn    = module.alert_topic.arn
  policy = data.aws_iam_policy_document.sns_policy.json
}

# ---------------------------------------------------------------------------
# EventBridge — critical/high findings → SNS
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "critical_findings" {
  name        = "${var.prefix}-guardduty-critical"
  description = "GuardDuty findings with severity >= ${var.min_severity}"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.min_severity] }]
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.critical_findings.name
  target_id = "sns-alert"
  arn       = module.alert_topic.arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      title       = "$.detail.title"
      description = "$.detail.description"
      account     = "$.detail.accountId"
      region      = "$.detail.region"
      type        = "$.detail.type"
    }
    input_template = <<-EOF
      "GuardDuty Finding [Severity: <severity>]"
      "Type: <type>"
      "Title: <title>"
      "Account: <account> | Region: <region>"
      "Description: <description>"
    EOF
  }
}

# ---------------------------------------------------------------------------
# EventBridge — all findings → S3 (optional archive)
# ---------------------------------------------------------------------------
module "findings_bucket" {
  count       = var.archive_findings ? 1 : 0
  source      = "../../modules/s3-bucket"
  bucket_name = "${var.prefix}-guardduty-findings"
  tags        = local.tags
}

data "aws_iam_policy_document" "firehose_findings" {
  count = var.archive_findings ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetBucketLocation"]
    resources = [
      module.findings_bucket[0].arn,
      "${module.findings_bucket[0].arn}/*",
    ]
  }
}

module "firehose_role" {
  count  = var.archive_findings ? 1 : 0
  source = "../../modules/iam-role"
  name   = "${var.prefix}-guardduty-firehose"
  assume_role_principals = [{
    type        = "Service"
    identifiers = ["firehose.amazonaws.com"]
  }]
  inline_policy = data.aws_iam_policy_document.firehose_findings[0].json
  tags          = local.tags
}

module "findings_firehose" {
  count         = var.archive_findings ? 1 : 0
  source        = "../../modules/kinesis-firehose"
  name          = "${var.prefix}-guardduty-archive"
  role_arn      = module.firehose_role[0].arn
  s3_bucket_arn = module.findings_bucket[0].arn
  s3_prefix     = "guardduty/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
  tags          = local.tags
}
