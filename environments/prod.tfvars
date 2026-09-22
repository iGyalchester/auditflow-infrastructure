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

# The console's custom domain. hosted_zone_name stays empty until the
# registrar/DNS question is settled (see stack/variables.tf); with it
# empty the stack outputs the validation CNAME to create by hand, and
# console_certificate_ready flips to true for the second apply.
console_domain            = "auditflow.areyouinquazzy.lol"
hosted_zone_name          = ""
console_certificate_ready = false

cognito_callback_urls = ["https://auditflow.areyouinquazzy.lol/callback"]
cognito_logout_urls   = ["https://auditflow.areyouinquazzy.lol/"]

# Required in prod - SNS sends a subscription-confirmation email on first apply.
alert_email = "borisgerard333@gmail.com"

# Flip to true only after images exist in ECR (see auditflow-platform's
# Deploy workflow) - Fargate + the ALB start billing on apply.
# The hourly-billed data plane (MSK Serverless, Aurora, the NAT gateway).
# Bills whether or not anything runs; flip together with ecs_enabled.
platform_enabled = true

ecs_enabled       = false
ecs_image_tag     = "latest"
ecs_desired_count = 2
