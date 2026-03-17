variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "security"
}

variable "alert_emails" {
  description = "Email addresses for alert notifications"
  type        = list(string)
}

variable "min_severity" {
  description = "Minimum GuardDuty severity to alert on (1-8.9). 4=Medium, 7=High"
  type        = number
  default     = 7
}

variable "enable_s3_protection" {
  description = "Enable GuardDuty S3 protection"
  type        = bool
  default     = true
}

variable "enable_eks_protection" {
  description = "Enable GuardDuty EKS audit log monitoring"
  type        = bool
  default     = true
}

variable "enable_malware_protection" {
  description = "Enable GuardDuty malware protection for EBS"
  type        = bool
  default     = false
}

variable "archive_findings" {
  description = "Archive all findings to S3 via Firehose"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
