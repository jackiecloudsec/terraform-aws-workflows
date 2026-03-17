variable "name" {
  description = "IAM role name"
  type        = string
}

variable "assume_role_principals" {
  description = "List of principals that can assume this role"
  type = list(object({
    type        = string
    identifiers = list(string)
    conditions  = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
}

variable "inline_policy" {
  description = "JSON-encoded inline policy (optional)"
  type        = string
  default     = null
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
