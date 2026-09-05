# Applied against ../stack with -var-file. The environment itself is passed
# separately (-var environment=prod), because it also chooses the state
# key and CI needs it before reading this file.
#
# Every value the environments differ on is set here explicitly. The root
# deliberately has no defaults for them: a forgotten value should fail the
# plan, not silently inherit another environment's number.

aws_region = "us-east-1"
azs        = ["us-east-1a", "us-east-1b", "us-east-1c"]
vpc_cidr   = "10.30.0.0/16"

single_nat_gateway = false

evidence_bucket_name  = "auditflow-evidence-prod-869935094950"
cognito_domain_prefix = "auditflow-prod-869935094950"

object_lock_retention_days = 2555

aurora_min_capacity_acu    = 1
aurora_max_capacity_acu    = 16
aurora_instance_count      = 3
aurora_deletion_protection = true
aurora_skip_final_snapshot = false

emr_max_concurrent_vcpus = 64

cognito_callback_urls = ["https://app.auditflow.example.com/callback"]
cognito_logout_urls   = ["https://app.auditflow.example.com/"]

# Required in prod - SNS sends a subscription-confirmation email on first apply.
alert_email = "borisgerard333@gmail.com"

# Flip to true only after images exist in ECR (see auditflow-platform's
# Deploy workflow) - Fargate + the ALB start billing on apply.
ecs_enabled       = false
ecs_image_tag     = "latest"
ecs_desired_count = 2
