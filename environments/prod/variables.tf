variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "single_nat_gateway" {
  description = "false in prod: one NAT Gateway per AZ so a single AZ outage doesn't take egress down for everyone."
  type        = bool
  default     = false
}

variable "evidence_bucket_name" {
  type = string
}

variable "object_lock_retention_days" {
  type    = number
  default = 2555 # 7 years - a common SOC2/HIPAA evidence retention baseline
}

variable "aurora_min_capacity_acu" {
  type    = number
  default = 1
}

variable "aurora_max_capacity_acu" {
  type    = number
  default = 16
}

variable "aurora_instance_count" {
  type    = number
  default = 3
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
  default = 64
}

variable "cognito_domain_prefix" {
  type = string
}

variable "cognito_callback_urls" {
  type    = list(string)
  default = ["https://app.auditflow.example.com/callback"]
}

variable "cognito_logout_urls" {
  type    = list(string)
  default = ["https://app.auditflow.example.com/"]
}

variable "alert_email" {
  type = string
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
