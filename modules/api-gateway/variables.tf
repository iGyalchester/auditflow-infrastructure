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

variable "integration_uri" {
  description = "Where routes proxy to (e.g. an ALB in front of ECS/EKS). Null until a compute target exists - the API, authorizer, and stage are still created so the endpoint/issuer wiring is stable, but no routes are attached and every request 404s."
  type        = string
  default     = null
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}
