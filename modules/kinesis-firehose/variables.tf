variable "name" {
  description = "Firehose delivery stream name"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN for Firehose"
  type        = string
}

variable "s3_bucket_arn" {
  description = "Destination S3 bucket ARN"
  type        = string
}

variable "s3_prefix" {
  description = "S3 key prefix for delivered files"
  type        = string
  default     = "logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
}

variable "s3_error_prefix" {
  description = "S3 key prefix for failed deliveries"
  type        = string
  default     = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
}

variable "buffering_size_mb" {
  description = "Buffer size in MB before delivery"
  type        = number
  default     = 5
}

variable "buffering_interval_sec" {
  description = "Buffer interval in seconds"
  type        = number
  default     = 300
}

variable "compression_format" {
  description = "Compression format (UNCOMPRESSED, GZIP, Snappy, HADOOP_SNAPPY)"
  type        = string
  default     = "GZIP"
}

variable "enable_lambda" {
  description = "Enable Lambda transformation"
  type        = bool
  default     = false
}

variable "lambda_arn" {
  description = "Lambda ARN for transformation (required if enable_lambda = true)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
