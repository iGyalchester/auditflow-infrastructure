locals {
  environment = "dev"
  name        = "auditflow-${local.environment}"
  tags = {
    Environment = local.environment
  }
}

module "network" {
  source = "../../modules/network"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  single_nat_gateway = var.single_nat_gateway
  tags               = local.tags
}

module "kms" {
  source = "../../modules/kms"

  name = local.name
  tags = local.tags
}

module "s3_evidence" {
  source = "../../modules/s3"

  bucket_name                = var.evidence_bucket_name
  kms_key_arn                = module.kms.key_arn
  object_lock_retention_days = var.object_lock_retention_days
  tags                       = local.tags
}

module "msk" {
  source = "../../modules/msk"

  name               = local.name
  vpc_id             = module.network.vpc_id
  vpc_cidr           = module.network.vpc_cidr
  private_subnet_ids = module.network.private_subnet_ids
  tags               = local.tags
}

module "aurora" {
  source = "../../modules/aurora"

  name                = local.name
  vpc_id              = module.network.vpc_id
  vpc_cidr            = module.network.vpc_cidr
  private_subnet_ids  = module.network.private_subnet_ids
  kms_key_arn         = module.kms.key_arn
  min_capacity_acu    = var.aurora_min_capacity_acu
  max_capacity_acu    = var.aurora_max_capacity_acu
  instance_count      = var.aurora_instance_count
  deletion_protection = var.aurora_deletion_protection
  skip_final_snapshot = var.aurora_skip_final_snapshot
  tags                = local.tags
}

module "glue" {
  source = "../../modules/glue"

  name                 = local.name
  evidence_bucket_name = module.s3_evidence.bucket_name
  evidence_bucket_arn  = module.s3_evidence.bucket_arn
  tags                 = local.tags
}

module "athena" {
  source = "../../modules/athena"

  name        = local.name
  kms_key_arn = module.kms.key_arn
  tags        = local.tags
}

module "emr" {
  source = "../../modules/emr"

  name                 = local.name
  vpc_id               = module.network.vpc_id
  vpc_cidr             = module.network.vpc_cidr
  private_subnet_ids   = module.network.private_subnet_ids
  evidence_bucket_arn  = module.s3_evidence.bucket_arn
  max_concurrent_vcpus = var.emr_max_concurrent_vcpus
  tags                 = local.tags
}

module "cognito" {
  source = "../../modules/cognito"

  name          = local.name
  domain_prefix = var.cognito_domain_prefix
  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls
  tags          = local.tags
}

module "api_gateway" {
  source = "../../modules/api-gateway"

  name                 = local.name
  aws_region           = var.aws_region
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_client_id    = module.cognito.user_pool_client_id

  enable_backend_integration  = var.ecs_enabled
  alb_listener_arn            = one(module.ecs[*].alb_listener_arn)
  vpc_link_subnet_ids         = module.network.private_subnet_ids
  vpc_link_security_group_ids = module.ecs[*].alb_security_group_id

  tags = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                        = local.name
  alert_email                 = var.alert_email
  aurora_instance_identifiers = module.aurora.instance_identifiers
  api_gateway_log_group_name  = module.api_gateway.access_log_group_name
  tags                        = local.tags
}


module "ecr" {
  source = "../../modules/ecr"

  name = local.name
  tags = local.tags
}

# Gated off by default: push images first (the app repo's Deploy workflow),
# THEN flip ecs_enabled - otherwise every task crash-loops pulling from an
# empty registry while the ALB and Fargate bill by the hour.
module "ecs" {
  source = "../../modules/ecs"
  count  = var.ecs_enabled ? 1 : 0

  name                    = local.name
  vpc_id                  = module.network.vpc_id
  vpc_cidr                = module.network.vpc_cidr
  private_subnet_ids      = module.network.private_subnet_ids
  repository_urls         = module.ecr.repository_urls
  image_tag               = var.ecs_image_tag
  desired_count           = var.ecs_desired_count
  kafka_bootstrap_servers = module.msk.bootstrap_brokers_sasl_iam
  msk_cluster_arn         = module.msk.cluster_arn
  aurora_endpoint         = module.aurora.cluster_endpoint
  aurora_secret_arn       = module.aurora.master_user_secret_arn
  evidence_bucket_name    = module.s3_evidence.bucket_name
  evidence_bucket_arn     = module.s3_evidence.bucket_arn
  cognito_user_pool_id    = module.cognito.user_pool_id
  cognito_client_id       = module.cognito.user_pool_client_id
  tags                    = local.tags
}
