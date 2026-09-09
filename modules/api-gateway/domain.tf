# The console's custom domain, e.g. auditflow.areyouinquazzy.lol. Nothing
# here exists until console_domain is set, so every environment can carry
# the code and only the one that owns the name pays for it.
#
# Three pieces: an ACM certificate validated by DNS, the API's custom
# domain name mapped onto the $default stage, and the DNS record that
# points the name at API Gateway's regional endpoint. The record is only
# written when the zone is in Route 53 (hosted_zone_name set); with the
# apex left at the registrar's DNS, the two outputs below are what to
# paste there (a CNAME for the domain, and the validation CNAME for the
# certificate), and Terraform waits for validation the same way.
locals {
  domain_enabled = var.console_domain != ""
  zone_enabled   = local.domain_enabled && var.hosted_zone_name != ""
}

data "aws_route53_zone" "console" {
  count        = local.zone_enabled ? 1 : 0
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_acm_certificate" "console" {
  count             = local.domain_enabled ? 1 : 0
  domain_name       = var.console_domain
  validation_method = "DNS"
  tags              = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "console_validation" {
  for_each = local.zone_enabled ? {
    for dvo in aws_acm_certificate.console[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = data.aws_route53_zone.console[0].zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# With the zone elsewhere, validation still has to complete before the
# domain name can use the certificate: apply once to get the validation
# CNAME from the output, create it at the registrar, and apply again.
resource "aws_acm_certificate_validation" "console" {
  count                   = local.domain_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.console[0].arn
  validation_record_fqdns = local.zone_enabled ? [for r in aws_route53_record.console_validation : r.fqdn] : null
}

resource "aws_apigatewayv2_domain_name" "console" {
  count       = local.domain_enabled ? 1 : 0
  domain_name = var.console_domain
  tags        = var.tags

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.console[0].certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "console" {
  count       = local.domain_enabled ? 1 : 0
  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.console[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

resource "aws_route53_record" "console" {
  count   = local.zone_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.console[0].zone_id
  name    = var.console_domain
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.console[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.console[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
