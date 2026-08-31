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

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}
