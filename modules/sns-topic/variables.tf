variable "name" {
  description = "SNS topic name"
  type        = string
}

variable "email_endpoints" {
  description = "List of email addresses to subscribe"
  type        = list(string)
  default     = []
}

variable "lambda_endpoints" {
  description = "Map of Lambda ARNs to subscribe"
  type        = map(string)
  default     = {}
}

variable "topic_policy" {
  description = "JSON-encoded topic policy (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
