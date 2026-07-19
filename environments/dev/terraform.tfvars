aws_region = "us-east-1"
azs        = ["us-east-1a", "us-east-1b"]
vpc_cidr   = "10.10.0.0/16"

single_nat_gateway = true

# Both of these must be globally unique - pick a real value before applying.
evidence_bucket_name  = "auditflow-evidence-dev-changeme"
cognito_domain_prefix = "auditflow-dev-changeme"

object_lock_retention_days = 90

aurora_min_capacity_acu    = 0.5
aurora_max_capacity_acu    = 2
aurora_instance_count      = 1
aurora_deletion_protection = false
aurora_skip_final_snapshot = true

emr_max_concurrent_vcpus = 16

cognito_callback_urls = ["http://localhost:5173/callback"]
cognito_logout_urls   = ["http://localhost:5173/"]

alert_email = null
