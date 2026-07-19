aws_region = "us-east-1"
azs        = ["us-east-1a", "us-east-1b", "us-east-1c"]
vpc_cidr   = "10.30.0.0/16"

single_nat_gateway = false

evidence_bucket_name  = "auditflow-evidence-prod-changeme"
cognito_domain_prefix = "auditflow-prod-changeme"

object_lock_retention_days = 2555

aurora_min_capacity_acu    = 1
aurora_max_capacity_acu    = 16
aurora_instance_count      = 3
aurora_deletion_protection = true
aurora_skip_final_snapshot = false

emr_max_concurrent_vcpus = 64

cognito_callback_urls = ["https://app.auditflow.example.com/callback"]
cognito_logout_urls   = ["https://app.auditflow.example.com/"]

# Required in prod - fill in the on-call address before applying.
alert_email = "changeme@example.com"
