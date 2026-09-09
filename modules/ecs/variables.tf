variable "name" {
  description = "Environment-scoped prefix, e.g. auditflow-dev."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "services" {
  description = "Platform services (name => container port). Must stay in sync with modules/ecr."
  type        = map(number)
  default = {
    api-gateway-service = 8080
    ingestion-service   = 8081
    enrichment-service  = 8082
    alerting-service    = 8083
  }
}

variable "repository_urls" {
  description = "Service name => ECR repository URL (from modules/ecr)."
  type        = map(string)
}

variable "image_tag" {
  description = "Image tag every service runs. The deploy workflow pushes :latest plus the git SHA."
  type        = string
  default     = "latest"
}

variable "desired_count" {
  description = "Tasks per service."
  type        = number
  default     = 1
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "kafka_bootstrap_servers" {
  description = "MSK IAM bootstrap broker string."
  type        = string
}

variable "msk_cluster_arn" {
  type = string
}

variable "aurora_endpoint" {
  type = string
}

variable "aurora_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed master credentials."
  type        = string
}

variable "evidence_bucket_name" {
  type = string
}

variable "evidence_bucket_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cognito_user_pool_id" {
  description = "Cognito user pool whose ID tokens api-gateway-service verifies (issuer is derived from it)."
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito app client id the gateway requires in the token audience."
  type        = string
}

variable "ingestion_tokens_secret_arn" {
  description = "Secrets Manager secret holding ingestion-service's AUDIT_INGESTION_TOKENS: a plain string of \"tenant=token,tenant=token\". Each token may only post events whose customerId is its own tenant. Empty = the endpoint is OPEN and any source can write as any customer, which is only ever acceptable in dev."
  type        = string
  default     = ""
}

variable "alert_slack_webhook_secret_arn" {
  description = "Secrets Manager secret holding the Slack incoming-webhook URL for alerting-service (plain string secret). Empty = Slack notifier logs only."
  type        = string
  default     = ""
}

variable "alert_email_from" {
  description = "SES-verified sender for alerting-service email notifications. Empty = email notifier logs only."
  type        = string
  default     = ""
}

variable "alert_email_to" {
  description = "Comma-separated recipients for alerting-service email notifications."
  type        = string
  default     = ""
}
