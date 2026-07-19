variable "name" {
  description = "Key alias suffix, e.g. \"auditflow-dev\"."
  type        = string
}

variable "deletion_window_in_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
