output "cluster_arn" {
  value = aws_msk_serverless_cluster.this.arn
}

output "bootstrap_brokers_sasl_iam" {
  description = "Bootstrap broker string for IAM-authenticated SASL clients (spring.kafka.bootstrap-servers)."
  value       = aws_msk_serverless_cluster.this.bootstrap_brokers_sasl_iam
}

output "security_group_id" {
  value = aws_security_group.msk_client.id
}
