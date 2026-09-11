resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP"
  tags          = var.tags
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito"

  jwt_configuration {
    audience = [var.cognito_client_id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

# The backend is the internal ALB in front of api-gateway-service (see
# modules/ecs), reached through a VPC link - a private ALB is not routable
# from API Gateway without one. Gated on enable_backend_integration (a
# plain bool, so count is known at plan time even while the ECS module's
# outputs are not). While disabled the API, authorizer, and stage still
# exist so the endpoint/issuer wiring is stable, but every request 404s.
# api-gateway-service's own token verification (SecurityConfig in the app
# repo) stays as defense in depth behind the JWT authorizer here.
resource "aws_apigatewayv2_vpc_link" "backend" {
  count              = var.enable_backend_integration ? 1 : 0
  name               = var.name
  subnet_ids         = var.vpc_link_subnet_ids
  security_group_ids = var.vpc_link_security_group_ids
  tags               = var.tags
}

resource "aws_apigatewayv2_integration" "backend" {
  count                  = var.enable_backend_integration ? 1 : 0
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = var.alb_listener_arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.backend[0].id
  payload_format_version = "1.0"

  # Tell the gateway who the caller actually is. Two hops sit in front of
  # it - this API and the internal ALB - so by the time a request reaches
  # the service the socket address is the load balancer, and every caller
  # in the world shares one rate-limit bucket.
  #
  # X-Forwarded-For is not the answer: every hop appends to it, so its
  # leading entry is whatever the client sent. A caller could rotate that
  # value and never be limited, or forge someone else's and have them
  # limited instead. $context.identity.sourceIp is the address API Gateway
  # saw, and "overwrite:" replaces any header the client supplied - so this
  # value is ours, not theirs. api-gateway-service reads it as
  # audit.rate-limit.client-ip-header in its aws profile.
  request_parameters = {
    "overwrite:header.x-client-ip" = "$context.identity.sourceIp"
  }
}

# Three routes, one integration.
#
#   ANY /api/{proxy+}       JWT   the API: no token, no request reaches the service
#   ANY /actuator/{proxy+}  JWT   the service opens /actuator/health for the
#                                 internal ALB's probe, which never traverses
#                                 this API; from the internet even health
#                                 needs a token, so nothing here is an
#                                 anonymous availability oracle
#   $default                NONE  everything else: the console's HTML and
#                                 JavaScript, a reload of a client-side route
#                                 such as /alerts, and "/" itself - the
#                                 browser has no token before it has loaded
#                                 the page that signs it in, and the page
#                                 holds no data
#
# HTTP API routing picks the most specific match, so /api/... and
# /actuator/... always land on their JWT routes, and $default takes the
# rest (including "/", which a /{proxy+} route would not match). The
# service still requires a token on /api/** and denies anything that is
# neither the console nor the API, so the open route exposes nothing new.
# The stage throttle below bounds what the open route can cost.
resource "aws_apigatewayv2_route" "api" {
  count              = var.enable_backend_integration ? 1 : 0
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /api/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.backend[0].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "actuator" {
  count              = var.enable_backend_integration ? 1 : 0
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /actuator/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.backend[0].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "console" {
  count              = var.enable_backend_integration ? 1 : 0
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "$default"
  target             = "integrations/${aws_apigatewayv2_integration.backend[0].id}"
  authorization_type = "NONE"
}

resource "aws_cloudwatch_log_group" "access_logs" {
  name              = "/auditflow/${var.name}/api-gateway"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  # The service's own limiter is per client address and covers /api/ only;
  # this is the aggregate ceiling for the whole API, open route included,
  # so an anonymous flood of page requests cannot fill the VPC link.
  default_route_settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      customerId     = "$context.authorizer.claims.custom:customer_id"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  tags = var.tags
}
