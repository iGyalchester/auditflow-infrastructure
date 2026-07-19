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
  description = "Where routes proxy to. Placeholder until a compute target (ECS/EKS/Fargate) is provisioned in a later phase - see README."
  type        = string
  default     = "http://placeholder.internal:8080/{proxy}"
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}
