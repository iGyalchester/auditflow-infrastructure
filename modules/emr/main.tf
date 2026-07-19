resource "aws_security_group" "emr" {
  name_prefix = "${var.name}-emr-"
  description = "EMR Serverless workers reading/writing the evidence lake."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Intra-VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${var.name}-emr" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_emrserverless_application" "spark" {
  name          = var.name
  release_label = var.release_label
  type          = "SPARK"

  network_configuration {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.emr.id]
  }

  maximum_capacity {
    cpu    = "${var.max_concurrent_vcpus}vCPU"
    memory = "${var.max_concurrent_vcpus * 2}GB"
  }

  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = 15
  }

  tags = var.tags
}

data "aws_iam_policy_document" "job_execution_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["emr-serverless.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "job_execution" {
  name               = "${var.name}-emr-job-execution"
  assume_role_policy = data.aws_iam_policy_document.job_execution_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "job_execution" {
  statement {
    sid       = "EvidenceLakeReadWrite"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [var.evidence_bucket_arn, "${var.evidence_bucket_arn}/*"]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "job_execution" {
  name   = "${var.name}-emr-job-execution"
  role   = aws_iam_role.job_execution.id
  policy = data.aws_iam_policy_document.job_execution.json
}
