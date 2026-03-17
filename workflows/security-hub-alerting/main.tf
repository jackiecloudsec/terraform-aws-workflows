###############################################################################
# Security Hub → EventBridge → SNS + S3 Archive
#
# Enables Security Hub with AWS Foundational Security Best Practices and
# CIS benchmarks, routes critical/high findings to SNS, and optionally
# archives all findings to S3 for long-term retention.
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

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
  tags = merge(var.tags, {
    Workflow = "security-hub-alerting"
  })
}

# ---------------------------------------------------------------------------
# Security Hub
# ---------------------------------------------------------------------------
resource "aws_securityhub_account" "this" {}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_aws_foundational ? 1 : 0
  depends_on    = [aws_securityhub_account.this]
  standards_arn = "arn:aws:securityhub:${local.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_cis_benchmark ? 1 : 0
  depends_on    = [aws_securityhub_account.this]
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"
}

resource "aws_securityhub_standards_subscription" "nist" {
  count         = var.enable_nist_framework ? 1 : 0
  depends_on    = [aws_securityhub_account.this]
  standards_arn = "arn:aws:securityhub:${local.region}::standards/nist-800-53/v/5.0.0"
}

# ---------------------------------------------------------------------------
# SNS — alert topic
# ---------------------------------------------------------------------------
module "alert_topic" {
  source          = "../../modules/sns-topic"
  name            = "${var.prefix}-securityhub-alerts"
  email_endpoints = var.alert_emails
  tags            = local.tags
}

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
# EventBridge — critical/high findings
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "critical_findings" {
  name        = "${var.prefix}-securityhub-critical"
  description = "Security Hub findings: CRITICAL or HIGH severity"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = var.severity_labels
        }
        Workflow = {
          Status = ["NEW"]
        }
        RecordState = ["ACTIVE"]
      }
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
      title      = "$.detail.findings[0].Title"
      severity   = "$.detail.findings[0].Severity.Label"
      account    = "$.detail.findings[0].AwsAccountId"
      resource   = "$.detail.findings[0].Resources[0].Id"
      standard   = "$.detail.findings[0].GeneratorId"
      compliance = "$.detail.findings[0].Compliance.Status"
    }
    input_template = <<-EOF
      "Security Hub Finding [<severity>]"
      "Title: <title>"
      "Account: <account>"
      "Resource: <resource>"
      "Standard: <standard>"
      "Compliance: <compliance>"
    EOF
  }
}

# ---------------------------------------------------------------------------
# S3 Archive (optional)
# ---------------------------------------------------------------------------
module "findings_bucket" {
  count       = var.archive_findings ? 1 : 0
  source      = "../../modules/s3-bucket"
  bucket_name = "${var.prefix}-securityhub-findings"
  tags        = local.tags
}

data "aws_iam_policy_document" "firehose_policy" {
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
  name   = "${var.prefix}-securityhub-firehose"
  assume_role_principals = [{
    type        = "Service"
    identifiers = ["firehose.amazonaws.com"]
  }]
  inline_policy = data.aws_iam_policy_document.firehose_policy[0].json
  tags          = local.tags
}

module "findings_firehose" {
  count         = var.archive_findings ? 1 : 0
  source        = "../../modules/kinesis-firehose"
  name          = "${var.prefix}-securityhub-archive"
  role_arn      = module.firehose_role[0].arn
  s3_bucket_arn = module.findings_bucket[0].arn
  s3_prefix     = "securityhub/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
  tags          = local.tags
}
