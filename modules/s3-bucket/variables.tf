variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "versioning" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (uses AES256 if null)"
  type        = string
  default     = null
}

variable "lifecycle_days" {
  description = "Days before transitioning to Glacier (0 to disable)"
  type        = number
  default     = 90
}

variable "expiration_days" {
  description = "Days before expiring objects (0 to disable)"
  type        = number
  default     = 365
}

variable "force_destroy" {
  description = "Allow bucket deletion even if not empty"
  type        = bool
  default     = false
}

variable "bucket_policy" {
  description = "JSON-encoded bucket policy (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
