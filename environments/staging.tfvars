# Applied against ../stack with -var-file. The environment itself is passed
# separately (-var environment=staging), because it also chooses the state
# key and CI needs it before reading this file.
#
# Every value the environments differ on is set here explicitly. The root
# deliberately has no defaults for them: a forgotten value should fail the
# plan, not silently inherit another environment's number.

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

# No custom domain here; the console is reached at the execute-api URL
# (see README, "The console's domain").
console_domain            = ""
hosted_zone_name          = ""
console_certificate_ready = false

cognito_callback_urls = ["https://staging.auditflow.example.com/callback"]
cognito_logout_urls   = ["https://staging.auditflow.example.com/"]

alert_email = null

# Flip to true only after images exist in ECR (see auditflow-platform's
# Deploy workflow) - Fargate + the ALB start billing on apply.
# The hourly-billed data plane (MSK Serverless, Aurora, the NAT gateway).
# Bills whether or not anything runs; flip together with ecs_enabled.
platform_enabled = true

ecs_enabled       = false
ecs_image_tag     = "latest"
ecs_desired_count = 1
