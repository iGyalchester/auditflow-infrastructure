output "state_bucket_name" {
  description = "S3 bucket name to reference from each environment's backend.hcl."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_region" {
  value = var.aws_region
}

output "github_actions_role_arn" {
  description = "Role ARN for the GitHub Actions workflow to assume via OIDC."
  value       = aws_iam_role.github_actions_deploy.arn
}
