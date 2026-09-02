# Fargate compute for the auditflow-platform services - the chosen answer
# to the "no compute target yet" open question. Serverless containers for
# the same reason as MSK/Aurora Serverless: no instances to size or patch
# while traffic is still unknown.
#
# Shape: every service runs as a plain Fargate service in the private
# subnets; only api-gateway-service sits behind the (internal) ALB, because
# it is the platform's single HTTP front door - the other services talk
# through Kafka, not HTTP. API Gateway reaches the internal ALB through a
# VPC link (wired in modules/api-gateway).

data "aws_region" "current" {}

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "services" {
  name              = "/auditflow/${var.name}/services"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# Networking: internal ALB in front of api-gateway-service only.
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Internal ALB fronting api-gateway-service; reached via the API Gateway VPC link."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from inside the VPC (VPC link ENIs)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "service" {
  name_prefix = "${var.name}-ecs-"
  description = "Fargate tasks; inbound only from the ALB."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Container ports from the ALB"
    from_port       = 8080
    to_port         = 8084
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-ecs" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.private_subnet_ids
  tags               = var.tags
}

resource "aws_lb_target_group" "api_gateway" {
  name        = "${var.name}-apigw"
  port        = var.services["api-gateway-service"]
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path = "/"
    # No actuator endpoint in the services yet, so "/" answers 404 from a
    # healthy Spring app - accept it until a real health endpoint exists.
    matcher             = "200-404"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# IAM: execution role (pull images, ship logs, inject the Aurora secret)
# and task role (what the running code may do: MSK via IAM, S3 evidence).
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = compact([var.aurora_secret_arn, var.alert_slack_webhook_secret_arn])
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${var.name}-aurora-secret-read"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

locals {
  # arn:aws:kafka:REGION:ACCT:cluster/NAME/UUID -> the topic/group ARN
  # families MSK IAM policies scope to.
  msk_topic_arns = "${replace(var.msk_cluster_arn, ":cluster/", ":topic/")}/*"
  msk_group_arns = "${replace(var.msk_cluster_arn, ":cluster/", ":group/")}/*"
}

data "aws_iam_policy_document" "task" {
  statement {
    sid       = "MskConnect"
    effect    = "Allow"
    actions   = ["kafka-cluster:Connect"]
    resources = [var.msk_cluster_arn]
  }

  statement {
    sid    = "MskTopics"
    effect = "Allow"
    actions = [
      "kafka-cluster:CreateTopic",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:WriteData",
      "kafka-cluster:ReadData",
    ]
    resources = [local.msk_topic_arns]
  }

  statement {
    sid    = "MskConsumerGroups"
    effect = "Allow"
    actions = [
      "kafka-cluster:AlterGroup",
      "kafka-cluster:DescribeGroup",
    ]
    resources = [local.msk_group_arns]
  }

  statement {
    sid    = "EvidenceWrite"
    effect = "Allow"
    # Write-only by design: the evidence store is append-only, and nothing
    # in the running services needs to read it back (reporting goes through
    # Athena).
    actions   = ["s3:PutObject"]
    resources = ["${var.evidence_bucket_arn}/*"]
  }

  # alerting-service sends through SES with the task role. Only granted
  # when a sender is configured; SES identity ARNs are per verified
  # address/domain, scope this to that identity once it exists.
  dynamic "statement" {
    for_each = var.alert_email_from != "" ? [1] : []
    content {
      actions   = ["ses:SendEmail", "ses:SendRawEmail"]
      resources = ["*"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "task" {
  name   = "${var.name}-platform-access"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}

# ---------------------------------------------------------------------------
# One task definition + service per platform service.
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "service" {
  for_each = var.services

  family                   = "${var.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${var.repository_urls[each.key]}:${var.image_tag}"
      essential = true
      portMappings = [
        { containerPort = each.value, protocol = "tcp" }
      ]
      environment = concat([
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
        { name = "KAFKA_BOOTSTRAP_SERVERS", value = var.kafka_bootstrap_servers },
        { name = "AURORA_JDBC_URL", value = "jdbc:postgresql://${var.aurora_endpoint}:5432/auditflow" },
        { name = "AUDIT_S3_BUCKET", value = var.evidence_bucket_name },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        # api-gateway-service verifies Cognito ID tokens itself (defense in
        # depth behind the API Gateway authorizer); the aws profile turns
        # enforcement on, these tell it which pool and app client to trust.
        { name = "COGNITO_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${var.cognito_user_pool_id}" },
        { name = "COGNITO_CLIENT_ID", value = var.cognito_client_id },
        ],
        # alerting-service notifier destinations. Blank = that notifier
        # logs instead of sending (the service's own dev default).
        each.key == "alerting-service" ? [
          { name = "ALERT_EMAIL_FROM", value = var.alert_email_from },
          { name = "ALERT_EMAIL_TO", value = var.alert_email_to },
        ] : []
      )
      secrets = concat([
        { name = "AURORA_USERNAME", valueFrom = "${var.aurora_secret_arn}:username::" },
        { name = "AURORA_PASSWORD", valueFrom = "${var.aurora_secret_arn}:password::" },
        ],
        # The Slack webhook URL is a credential (anyone holding it can post
        # to the channel), so it comes from Secrets Manager, never plain env.
        each.key == "alerting-service" && var.alert_slack_webhook_secret_arn != "" ? [
          { name = "ALERT_SLACK_WEBHOOK_URL", valueFrom = var.alert_slack_webhook_secret_arn },
        ] : []
      )
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.services.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = each.key
        }
      }
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "service" {
  for_each = var.services

  name            = each.key
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = each.key == "api-gateway-service" ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.api_gateway.arn
      container_name   = each.key
      container_port   = each.value
    }
  }

  # New images are rolled out by the app repo's deploy workflow
  # (force-new-deployment), not by Terraform re-applies.
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.http]

  tags = var.tags
}
