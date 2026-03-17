variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "network"
}

variable "vpc_ids" {
  description = "List of VPC IDs to enable flow logs on"
  type        = list(string)
}

variable "s3_bucket_name" {
  description = "S3 bucket name for flow logs"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (optional)"
  type        = string
  default     = null
}

variable "glue_database_name" {
  description = "Glue catalog database name"
  type        = string
  default     = "vpc_flow_logs"
}

variable "log_format" {
  description = "VPC flow log format string (null = default)"
  type        = string
  default     = null
}

variable "query_byte_limit" {
  description = "Athena query byte scan limit (cost protection)"
  type        = number
  default     = 10737418240 # 10 GB
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
