variable "name" {
  type = string
}

variable "alert_email" {
  description = "Email address subscribed to the alerts SNS topic. Leave null to skip - useful before anyone owns on-call for this environment."
  type        = string
  default     = null
}

variable "aurora_instance_identifiers" {
  type    = list(string)
  default = []
}

variable "api_gateway_log_group_name" {
  type = string
}

variable "cpu_alarm_threshold" {
  type    = number
  default = 80
}

variable "tags" {
  type    = map(string)
  default = {}
}
