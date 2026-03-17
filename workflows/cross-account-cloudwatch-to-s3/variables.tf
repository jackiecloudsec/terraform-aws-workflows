variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "central-logging"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for log delivery"
  type        = string
}

variable "source_account_ids" {
  description = "AWS account IDs allowed to send logs"
  type        = list(string)
}

variable "source_log_groups" {
  description = "Map of name => CloudWatch log group ARN to subscribe"
  type        = map(string)
  default     = {}
}

variable "subscription_filter_pattern" {
  description = "CloudWatch subscription filter pattern (empty = all)"
  type        = string
  default     = ""
}

variable "enable_lambda_transform" {
  description = "Enable Lambda transformation before S3 delivery"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 encryption (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
