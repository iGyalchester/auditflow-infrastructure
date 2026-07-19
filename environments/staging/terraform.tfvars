aws_region = "us-east-1"
azs        = ["us-east-1a", "us-east-1b"]
vpc_cidr   = "10.20.0.0/16"

single_nat_gateway = true

evidence_bucket_name  = "auditflow-evidence-staging-869935094950"
cognito_domain_prefix = "auditflow-staging-869935094950"

object_lock_retention_days = 365

aurora_min_capacity_acu    = 0.5
aurora_max_capacity_acu    = 4
aurora_instance_count      = 2
aurora_deletion_protection = true
aurora_skip_final_snapshot = false

emr_max_concurrent_vcpus = 32

cognito_callback_urls = ["https://staging.auditflow.example.com/callback"]
cognito_logout_urls   = ["https://staging.auditflow.example.com/"]

alert_email = null
