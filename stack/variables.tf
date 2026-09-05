variable "environment" {
  description = "Which environment this root is applied as. Chooses the state key, the resource name prefix and the tfvars file."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "single_nat_gateway" {
  type = bool
}

variable "evidence_bucket_name" {
  description = "Must be globally unique across all of S3."
  type        = string
}

variable "object_lock_retention_days" {
  type = number
}

variable "aurora_min_capacity_acu" {
  type = number
}

variable "aurora_max_capacity_acu" {
  type = number
}

variable "aurora_instance_count" {
  type = number
}

variable "aurora_deletion_protection" {
  type = bool
}

variable "aurora_skip_final_snapshot" {
  type = bool
}

variable "emr_max_concurrent_vcpus" {
  type = number
}

variable "cognito_domain_prefix" {
  description = "Must be globally unique across Cognito in this region."
  type        = string
}

variable "cognito_callback_urls" {
  type = list(string)
}

variable "cognito_logout_urls" {
  type = list(string)
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
  type = number
}

variable "ingestion_tokens_secret_arn" {
  description = "Secrets Manager secret (plain string) holding AUDIT_INGESTION_TOKENS as \"tenant=token,tenant=token\". Each token may only post events whose customerId is its own tenant. Empty = the ingestion endpoint is open to any customerId, which is only acceptable in dev."
  type        = string
  default     = ""

  # Open ingestion means any source can write events as any customer, which
  # is a forged audit trail. Tolerable in dev, never outside it - so the
  # apply refuses rather than quietly bringing up an open endpoint.
  #
  # This used to live only in prod's copy of variables.tf, which meant
  # staging could have been brought up open and nothing would have said so.
  validation {
    condition = (
      var.environment == "dev"
      || !var.ecs_enabled
      || var.ingestion_tokens_secret_arn != ""
    )
    error_message = "ingestion_tokens_secret_arn is required outside dev when ecs_enabled is true: an open ingestion endpoint lets any source forge another customer's audit trail."
  }
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
