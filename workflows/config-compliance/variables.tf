variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "compliance"
}

variable "s3_bucket_name" {
  description = "S3 bucket for Config snapshots and history"
  type        = string
}

variable "alert_emails" {
  description = "Email addresses for non-compliance alerts"
  type        = list(string)
}

variable "snapshot_frequency" {
  description = "Config snapshot delivery frequency"
  type        = string
  default     = "Six_Hours"
}

variable "enable_all_rules" {
  description = "Enable all managed Config rules"
  type        = bool
  default     = true
}

variable "enabled_rule_names" {
  description = "List of rule names to enable (only used if enable_all_rules = false)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
