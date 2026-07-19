output "workgroup_name" {
  value = aws_athena_workgroup.this.name
}

output "results_bucket_name" {
  value = aws_s3_bucket.results.bucket
}
