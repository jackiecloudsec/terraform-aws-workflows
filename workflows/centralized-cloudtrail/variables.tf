variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "central"
}

variable "s3_bucket_name" {
  description = "S3 bucket for CloudTrail logs"
  type        = string
}

variable "multi_region" {
  description = "Enable multi-region trail"
  type        = bool
  default     = true
}

variable "organization_id" {
  description = "AWS Organization ID (enables org-wide trail if set)"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null
}

variable "alert_emails" {
  description = "Email addresses for security alerts"
  type        = list(string)
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
