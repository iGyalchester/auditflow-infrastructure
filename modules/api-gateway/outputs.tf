output "api_endpoint" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "access_log_group_name" {
  value = aws_cloudwatch_log_group.access_logs.name
}

# When the zone is not in Route 53, these are the two records to create
# at the registrar: the certificate's validation CNAME, and the console
# name pointing at API Gateway's regional endpoint.
output "console_domain_target" {
  description = "CNAME target for console_domain (empty until a domain is configured)."
  value       = try(aws_apigatewayv2_domain_name.console[0].domain_name_configuration[0].target_domain_name, "")
}

output "console_certificate_validation_records" {
  description = "DNS records ACM needs to see before it issues the certificate."
  value = try([
    for dvo in aws_acm_certificate.console[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ], [])
}
