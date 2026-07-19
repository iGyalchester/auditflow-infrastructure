output "application_id" {
  value = aws_emrserverless_application.spark.id
}

output "job_execution_role_arn" {
  value = aws_iam_role.job_execution.arn
}
