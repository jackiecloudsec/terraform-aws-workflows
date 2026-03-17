variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "security"
}

variable "alert_emails" {
  description = "Email addresses for alert notifications"
  type        = list(string)
}

variable "severity_labels" {
  description = "Severity labels to alert on"
  type        = list(string)
  default     = ["CRITICAL", "HIGH"]
}

variable "enable_aws_foundational" {
  description = "Enable AWS Foundational Security Best Practices"
  type        = bool
  default     = true
}

variable "enable_cis_benchmark" {
  description = "Enable CIS AWS Foundations Benchmark"
  type        = bool
  default     = true
}

variable "enable_nist_framework" {
  description = "Enable NIST 800-53 framework"
  type        = bool
  default     = false
}

variable "archive_findings" {
  description = "Archive all findings to S3"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
