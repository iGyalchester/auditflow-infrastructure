output "user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.this.arn
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "hosted_ui_domain" {
  value = aws_cognito_user_pool_domain.this.domain
}

# The hosted UI origin. The console needs it for sign-out: Cognito's OIDC
# discovery document publishes no end_session_endpoint, so the client has
# to be told where /logout lives.
output "hosted_ui_url" {
  value = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

output "operators_group_name" {
  value = aws_cognito_user_group.operators.name
}
