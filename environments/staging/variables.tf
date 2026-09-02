variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "evidence_bucket_name" {
  type = string
}

variable "object_lock_retention_days" {
  type    = number
  default = 365
}

variable "aurora_min_capacity_acu" {
  type    = number
  default = 0.5
}

variable "aurora_max_capacity_acu" {
  type    = number
  default = 4
}

variable "aurora_instance_count" {
  type    = number
  default = 2
}

variable "aurora_deletion_protection" {
  type    = bool
  default = true
}

variable "aurora_skip_final_snapshot" {
  type    = bool
  default = false
}

variable "emr_max_concurrent_vcpus" {
  type    = number
  default = 32
}

variable "cognito_domain_prefix" {
  type = string
}

variable "cognito_callback_urls" {
  type    = list(string)
  default = ["https://staging.auditflow.example.com/callback"]
}

variable "cognito_logout_urls" {
  type    = list(string)
  default = ["https://staging.auditflow.example.com/"]
}

variable "alert_email" {
  type    = string
  default = null
}


variable "ecs_enabled" {
  description = "Provision the Fargate services + internal ALB. Off by default: push images first (Deploy workflow in auditflow-platform), then flip - compute bills from the moment this applies."
  type        = bool
  default     = false
}

variable "ecs_image_tag" {
  type    = string
  default = "latest"
}

variable "ecs_desired_count" {
  type    = number
  default = 1
}

variable "alert_slack_webhook_secret_arn" {
  description = "Secrets Manager secret (plain string) holding the Slack incoming-webhook URL for alert notifications. Empty = Slack alerts are logged, not sent."
  type        = string
  default     = ""
}

variable "alert_email_from" {
  description = "SES-verified sender for alert emails. Empty = email alerts are logged, not sent."
  type        = string
  default     = ""
}

variable "alert_email_to" {
  description = "Comma-separated recipients for alert emails."
  type        = string
  default     = ""
}
