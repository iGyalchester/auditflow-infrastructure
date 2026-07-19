output "cluster_endpoint" {
  value = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  value = aws_rds_cluster.this.reader_endpoint
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN holding the auto-generated/rotated master password."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  value = aws_security_group.aurora.id
}

output "instance_identifiers" {
  value = aws_rds_cluster_instance.this[*].identifier
}
