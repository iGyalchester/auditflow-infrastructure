output "api_endpoint" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "access_log_group_name" {
  value = aws_cloudwatch_log_group.access_logs.name
}
