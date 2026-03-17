###############################################################################
# Cross-Account CloudWatch → Firehose → Lambda → S3
#
# Source accounts ship CloudWatch logs via subscription filter to a Kinesis
# Firehose in the central (security) account. An optional Lambda transforms
# the log data before Firehose delivers it to S3, partitioned by date.
#
# Accounts involved:
#   - Source account(s): CloudWatch Logs + subscription filter + IAM role
#   - Central account:   Firehose + Lambda (optional) + S3 bucket + IAM roles
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
    Workflow = "cross-account-cloudwatch-to-s3"
  })
}

# ---------------------------------------------------------------------------
# S3 — log destination bucket
# ---------------------------------------------------------------------------
module "log_bucket" {
  source      = "../../modules/s3-bucket"
  bucket_name = var.s3_bucket_name
  versioning  = true
  kms_key_arn = var.kms_key_arn
  tags        = local.tags
}

# ---------------------------------------------------------------------------
# IAM — Firehose delivery role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "firehose_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [
      module.log_bucket.arn,
      "${module.log_bucket.arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.enable_lambda_transform ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "lambda:InvokeFunction",
        "lambda:GetFunctionConfiguration",
      ]
      resources = [module.transform_lambda[0].arn]
    }
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
      ]
      resources = [var.kms_key_arn]
    }
  }
}

module "firehose_role" {
  source = "../../modules/iam-role"
  name   = "${var.prefix}-firehose-delivery"
  assume_role_principals = [{
    type        = "Service"
    identifiers = ["firehose.amazonaws.com"]
  }]
  inline_policy = data.aws_iam_policy_document.firehose_policy.json
  tags          = local.tags
}

# ---------------------------------------------------------------------------
# Lambda — optional log transformation
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_policy" {
  count = var.enable_lambda_transform ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "firehose:PutRecordBatch",
    ]
    resources = [module.firehose.arn]
  }
}

module "lambda_role" {
  count  = var.enable_lambda_transform ? 1 : 0
  source = "../../modules/iam-role"
  name   = "${var.prefix}-firehose-transform"
  assume_role_principals = [{
    type        = "Service"
    identifiers = ["lambda.amazonaws.com"]
  }]
  inline_policy = data.aws_iam_policy_document.lambda_policy[0].json
  tags          = local.tags
}

module "transform_lambda" {
  count         = var.enable_lambda_transform ? 1 : 0
  source        = "../../modules/lambda-function"
  function_name = "${var.prefix}-log-transform"
  role_arn      = module.lambda_role[0].arn
  source_dir    = "${path.module}/lambda"
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 256
  tags          = local.tags
}

# ---------------------------------------------------------------------------
# Firehose — delivery stream
# ---------------------------------------------------------------------------
module "firehose" {
  source         = "../../modules/kinesis-firehose"
  name           = "${var.prefix}-log-delivery"
  role_arn       = module.firehose_role.arn
  s3_bucket_arn  = module.log_bucket.arn
  s3_prefix      = "cloudwatch-logs/account=!{partitionKeyFromQuery:accountId}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
  enable_lambda  = var.enable_lambda_transform
  lambda_arn     = var.enable_lambda_transform ? module.transform_lambda[0].arn : ""
  tags           = local.tags
}

# ---------------------------------------------------------------------------
# IAM — cross-account role for CloudWatch Logs subscription
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "cw_to_firehose_policy" {
  statement {
    effect    = "Allow"
    actions   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
    resources = [module.firehose.arn]
  }
}

module "cw_subscription_role" {
  source = "../../modules/iam-role"
  name   = "${var.prefix}-cw-to-firehose"
  assume_role_principals = [{
    type        = "Service"
    identifiers = ["logs.${local.region}.amazonaws.com"]
    conditions = [{
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = [for acct in var.source_account_ids : "arn:aws:logs:${local.region}:${acct}:*"]
    }]
  }]
  inline_policy = data.aws_iam_policy_document.cw_to_firehose_policy.json
  tags          = local.tags
}

# ---------------------------------------------------------------------------
# Firehose destination policy — allow source accounts
# ---------------------------------------------------------------------------
resource "aws_kinesis_firehose_delivery_stream" "destination_policy" {
  count = 0 # placeholder — destination policies are set via CW subscription
}

# ---------------------------------------------------------------------------
# CloudWatch subscription filters (one per source log group)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_subscription_filter" "source" {
  for_each = var.source_log_groups

  name            = "${var.prefix}-${each.key}"
  log_group_name  = each.value
  filter_pattern  = var.subscription_filter_pattern
  destination_arn = module.firehose.arn
  role_arn        = module.cw_subscription_role.arn
}
