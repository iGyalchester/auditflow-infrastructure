resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == null ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  count               = length(var.aurora_instance_identifiers)
  alarm_name          = "${var.name}-aurora-cpu-high-${var.aurora_instance_identifiers[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  period              = 300
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Aurora instance ${var.aurora_instance_identifiers[count.index]} CPU above ${var.cpu_alarm_threshold}% for 15 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.aurora_instance_identifiers[count.index]
  }

  tags = var.tags
}

# Surfaces failures at the edge (auth rejections, backend errors) before
# they show up as a customer complaint.
resource "aws_cloudwatch_log_metric_filter" "api_gateway_5xx" {
  name           = "${var.name}-api-gateway-5xx"
  log_group_name = var.api_gateway_log_group_name
  pattern        = "{ $.status >= 500 }"

  metric_transformation {
    name      = "${var.name}ApiGateway5xxCount"
    namespace = "AuditFlow/${var.name}"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "${var.name}-api-gateway-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 300
  namespace           = aws_cloudwatch_log_metric_filter.api_gateway_5xx.metric_transformation[0].namespace
  metric_name         = aws_cloudwatch_log_metric_filter.api_gateway_5xx.metric_transformation[0].name
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_description   = "More than 10 5xx responses from the API gateway in 5 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = var.tags
}
