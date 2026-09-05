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

cognito_callback_urls = ["http://localhost:5173/callback"]
cognito_logout_urls   = ["http://localhost:5173/"]

alert_email = null

# Flip to true only after images exist in ECR (see auditflow-platform's
# Deploy workflow) - Fargate + the ALB start billing on apply.
ecs_enabled       = false
ecs_image_tag     = "latest"
ecs_desired_count = 1
