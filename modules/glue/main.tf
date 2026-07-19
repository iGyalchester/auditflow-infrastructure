resource "aws_glue_catalog_database" "evidence" {
  name = replace(var.name, "-", "_")
}

data "aws_iam_policy_document" "crawler_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "crawler" {
  name               = "${var.name}-glue-crawler"
  assume_role_policy = data.aws_iam_policy_document.crawler_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "crawler_service" {
  role       = aws_iam_role.crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "crawler_s3" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [var.evidence_bucket_arn, "${var.evidence_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "crawler_s3" {
  name   = "${var.name}-crawler-s3-read"
  role   = aws_iam_role.crawler.id
  policy = data.aws_iam_policy_document.crawler_s3.json
}

resource "aws_glue_crawler" "evidence" {
  name          = "${var.name}-evidence-crawler"
  role          = aws_iam_role.crawler.arn
  database_name = aws_glue_catalog_database.evidence.name
  schedule      = var.crawler_schedule

  s3_target {
    path = "s3://${var.evidence_bucket_name}/"
  }

  # New partitions only add columns/tables here; they never remove or
  # rewrite evidence that's already been catalogued.
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  tags = var.tags
}
