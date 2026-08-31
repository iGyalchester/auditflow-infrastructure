output "vpc_id" {
  value = module.network.vpc_id
}

output "evidence_bucket_name" {
  value = module.s3_evidence.bucket_name
}

output "msk_bootstrap_brokers" {
  value = module.msk.bootstrap_brokers_sasl_iam
}

output "aurora_cluster_endpoint" {
  value = module.aurora.cluster_endpoint
}

output "aurora_master_user_secret_arn" {
  value = module.aurora.master_user_secret_arn
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  value = module.cognito.user_pool_client_id
}

output "api_gateway_endpoint" {
  value = module.api_gateway.api_endpoint
}

output "athena_workgroup_name" {
  value = module.athena.workgroup_name
}

output "glue_database_name" {
  value = module.glue.database_name
}

output "emr_application_id" {
  value = module.emr.application_id
}


output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}
