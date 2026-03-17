variable "name" {
  description = "EventBridge rule name"
  type        = string
}

variable "description" {
  description = "Rule description"
  type        = string
  default     = ""
}

variable "event_pattern" {
  description = "JSON event pattern"
  type        = string
}

variable "targets" {
  description = "Map of targets for the rule"
  type        = map(any)
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
