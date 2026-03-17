###############################################################################
# AWS Config → SNS + S3
#
# Enables AWS Config with a recorder, delivery channel, and a set of
# managed rules for common security/compliance checks. Non-compliant
# resources trigger SNS alerts via EventBridge.
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
    Workflow = "config-compliance"
  })
}

# ---------------------------------------------------------------------------
# S3 — Config snapshot + history delivery
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "config_bucket_policy" {
  statement {
    sid     = "AWSConfigBucketPermissionsCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }

  statement {
    sid     = "AWSConfigBucketDelivery"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}/AWSLogs/${local.account_id}/Config/*"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

module "config_bucket" {
  source        = "../../modules/s3-bucket"
  bucket_name   = var.s3_bucket_name
  versioning    = true
  bucket_policy = data.aws_iam_policy_document.config_bucket_policy.json
  tags          = local.tags
}

# ---------------------------------------------------------------------------
# IAM — Config service role
# ---------------------------------------------------------------------------
module "config_role" {
  source = "../../modules/iam-role"
  name   = "${var.prefix}-config-recorder"
  assume_role_principals = [{
    type        = "Service"
    identifiers = ["config.amazonaws.com"]
  }]
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"]
  tags                = local.tags
}

data "aws_iam_policy_document" "config_s3" {
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetBucketAcl"]
    resources = [
      module.config_bucket.arn,
      "${module.config_bucket.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "config_s3" {
  name   = "${var.prefix}-config-s3"
  role   = module.config_role.id
  policy = data.aws_iam_policy_document.config_s3.json
}

# ---------------------------------------------------------------------------
# AWS Config — recorder + delivery channel
# ---------------------------------------------------------------------------
resource "aws_config_configuration_recorder" "this" {
  name     = "${var.prefix}-recorder"
  role_arn = module.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.prefix}-delivery"
  s3_bucket_name = module.config_bucket.bucket
  depends_on     = [aws_config_configuration_recorder.this]

  snapshot_delivery_properties {
    delivery_frequency = var.snapshot_frequency
  }
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

# ---------------------------------------------------------------------------
# SNS — compliance alerts
# ---------------------------------------------------------------------------
module "alert_topic" {
  source          = "../../modules/sns-topic"
  name            = "${var.prefix}-config-alerts"
  email_endpoints = var.alert_emails
  tags            = local.tags
}

data "aws_iam_policy_document" "sns_events" {
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
  policy = data.aws_iam_policy_document.sns_events.json
}

# ---------------------------------------------------------------------------
# EventBridge — non-compliant resource changes → SNS
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "non_compliant" {
  name        = "${var.prefix}-config-noncompliant"
  description = "AWS Config: resource became NON_COMPLIANT"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      messageType       = ["ComplianceChangeNotification"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.non_compliant.name
  target_id = "sns-alert"
  arn       = module.alert_topic.arn
}

# ---------------------------------------------------------------------------
# Managed Config Rules
# ---------------------------------------------------------------------------
locals {
  config_rules = {
    s3-bucket-public-read-prohibited = {
      source     = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
      input      = {}
    }
    s3-bucket-public-write-prohibited = {
      source     = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
      input      = {}
    }
    s3-bucket-server-side-encryption-enabled = {
      source     = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
      input      = {}
    }
    s3-bucket-versioning-enabled = {
      source     = "S3_BUCKET_VERSIONING_ENABLED"
      input      = {}
    }
    encrypted-volumes = {
      source     = "ENCRYPTED_VOLUMES"
      input      = {}
    }
    rds-storage-encrypted = {
      source     = "RDS_STORAGE_ENCRYPTED"
      input      = {}
    }
    root-account-mfa-enabled = {
      source     = "ROOT_ACCOUNT_MFA_ENABLED"
      input      = {}
    }
    iam-root-access-key-check = {
      source     = "IAM_ROOT_ACCESS_KEY_CHECK"
      input      = {}
    }
    iam-password-policy = {
      source     = "IAM_PASSWORD_POLICY"
      input      = {
        RequireUppercaseCharacters = "true"
        RequireLowercaseCharacters = "true"
        RequireSymbols             = "true"
        RequireNumbers             = "true"
        MinimumPasswordLength      = "14"
        PasswordReusePrevention    = "24"
        MaxPasswordAge             = "90"
      }
    }
    mfa-enabled-for-iam-console-access = {
      source     = "MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS"
      input      = {}
    }
    restricted-ssh = {
      source     = "INCOMING_SSH_DISABLED"
      input      = {}
    }
    restricted-common-ports = {
      source     = "RESTRICTED_INCOMING_TRAFFIC"
      input      = {
        blockedPort1 = "20"
        blockedPort2 = "21"
        blockedPort3 = "3389"
        blockedPort4 = "3306"
        blockedPort5 = "4333"
      }
    }
    cloudtrail-enabled = {
      source     = "CLOUD_TRAIL_ENABLED"
      input      = {}
    }
    multi-region-cloudtrail-enabled = {
      source     = "MULTI_REGION_CLOUD_TRAIL_ENABLED"
      input      = {}
    }
    guardduty-enabled-centralized = {
      source     = "GUARDDUTY_ENABLED_CENTRALIZED"
      input      = {}
    }
    vpc-flow-logs-enabled = {
      source     = "VPC_FLOW_LOGS_ENABLED"
      input      = {}
    }
  }

  enabled_rules = var.enable_all_rules ? local.config_rules : {
    for k, v in local.config_rules : k => v if contains(var.enabled_rule_names, k)
  }
}

resource "aws_config_config_rule" "this" {
  for_each   = local.enabled_rules
  name       = "${var.prefix}-${each.key}"
  depends_on = [aws_config_configuration_recorder.this]

  source {
    owner             = "AWS"
    source_identifier = each.value.source
  }

  input_parameters = length(each.value.input) > 0 ? jsonencode(each.value.input) : null

  tags = local.tags
}
