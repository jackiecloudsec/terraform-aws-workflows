variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN for the function"
  type        = string
}

variable "handler" {
  description = "Function entrypoint"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Timeout in seconds"
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Memory in MB"
  type        = number
  default     = 128
}

variable "source_dir" {
  description = "Path to the Lambda source directory"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "invoke_permissions" {
  description = "Map of services allowed to invoke this function"
  type = map(object({
    principal  = string
    source_arn = string
  }))
  default = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
