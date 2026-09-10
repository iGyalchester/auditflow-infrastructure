variable "name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cognito_user_pool_id" {
  type = string
}

variable "cognito_client_id" {
  type = string
}

variable "enable_backend_integration" {
  description = "Attach the VPC-link route to the ECS ALB. Kept as an explicit bool (mirroring ecs_enabled) so resource counts are plan-time known."
  type        = bool
  default     = false
}

variable "alb_listener_arn" {
  description = "Internal ALB listener ARN the VPC-link integration targets. Required when enable_backend_integration is true."
  type        = string
  default     = null
}

variable "vpc_link_subnet_ids" {
  description = "Private subnets the VPC link's ENIs live in."
  type        = list(string)
  default     = []
}

variable "vpc_link_security_group_ids" {
  description = "Security groups for the VPC link ENIs (the ALB's group works: it already admits VPC-internal HTTP)."
  type        = list(string)
  default     = []
}

variable "throttling_rate_limit" {
  description = "Stage-wide steady-state requests per second across every route (the service limiter is per client on /api/ only)."
  type        = number
  default     = 100
}

variable "throttling_burst_limit" {
  description = "Stage-wide burst across every route."
  type        = number
  default     = 200
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "console_domain" {
  description = "Custom domain for the console and API, e.g. auditflow.areyouinquazzy.lol. Empty = no certificate, no domain name, no DNS: the execute-api URL stays the only entry."
  type        = string
  default     = ""
}

variable "hosted_zone_name" {
  description = "Public Route 53 zone that holds console_domain (e.g. areyouinquazzy.lol), when this account hosts it. Empty = the zone lives elsewhere; the outputs then say which CNAMEs to create by hand."
  type        = string
  default     = ""
}
