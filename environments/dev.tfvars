# Applied against ../stack with -var-file. The environment itself is passed
# separately (-var environment=dev), because it also chooses the state
# key and CI needs it before reading this file.
#
# Every value the environments differ on is set here explicitly. The root
# deliberately has no defaults for them: a forgotten value should fail the
# plan, not silently inherit another environment's number.

aws_region = "us-east-1"
azs        = ["us-east-1a", "us-east-1b"]
vpc_cidr   = "10.10.0.0/16"

single_nat_gateway = true

evidence_bucket_name  = "auditflow-evidence-dev-869935094950"
cognito_domain_prefix = "auditflow-dev-869935094950"

object_lock_retention_days = 90

aurora_min_capacity_acu    = 0.5
aurora_max_capacity_acu    = 2
aurora_instance_count      = 1
aurora_deletion_protection = false
aurora_skip_final_snapshot = true

emr_max_concurrent_vcpus = 16

# The Vite dev server only. The custom domain belongs to prod; a callback
# URL is a redirect target the pool trusts, so it is listed only where the
# name is served. While dev runs the console from its execute-api origin,
# add that origin here after the first apply (README, "The console's
# domain") - the pool cannot reference the API's URL in Terraform without
# a cycle.
# No custom domain here; the console is reached at the execute-api URL
# (see README, "The console's domain").
console_domain            = ""
hosted_zone_name          = ""
console_certificate_ready = false

cognito_callback_urls = ["http://localhost:5173/callback"]
cognito_logout_urls   = ["http://localhost:5173/"]

alert_email = null

# Flip to true only after images exist in ECR (see auditflow-platform's
# Deploy workflow) - Fargate + the ALB start billing on apply.
ecs_enabled       = false
ecs_image_tag     = "latest"
ecs_desired_count = 1
