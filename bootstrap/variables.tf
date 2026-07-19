variable "aws_region" {
  description = "AWS region the state bucket and OIDC role live in."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform remote state."
  type        = string
}

variable "github_org" {
  description = "GitHub organization/user that owns the infrastructure repos allowed to assume the CI deploy role."
  type        = string
}

variable "github_repos" {
  description = "Repo names (under github_org) whose GitHub Actions workflows may assume the CI deploy role."
  type        = list(string)
  default     = ["auditflow-infrastructure", "auditflow-platform"]
}
