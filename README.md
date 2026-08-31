# AuditFlow Infrastructure

Terraform for AuditFlow's AWS infrastructure. Companion to the
[`auditflow-platform`](../auditflow-platform) application repo.

## Layout

```
bootstrap/            One-time, hand-applied: Terraform state bucket + GitHub OIDC role.
modules/
  network/            VPC, public/private subnets across N AZs, NAT, S3 gateway endpoint.
  kms/                 Shared CMK for encryption at rest.
  s3/                  Evidence bucket - versioned, Object Lock (COMPLIANCE), deny-delete policy.
  msk/                 MSK Serverless Kafka cluster, IAM-authenticated.
  aurora/              Aurora PostgreSQL Serverless v2, RDS-managed master password.
  glue/                Glue catalog + crawler over the evidence bucket.
  athena/              Athena workgroup (forced encryption) + query-results bucket.
  emr/                 EMR Serverless Spark application for anomaly-detection batch jobs.
  cognito/             User pool (with a customer_id custom attribute) + app client.
  api-gateway/         HTTP API Gateway with a Cognito JWT authorizer + VPC link to the ECS ALB.
  ecr/                 One image repository per platform service (scan-on-push, lifecycle-pruned).
  ecs/                 Fargate services for auditflow-platform, internal ALB in front of api-gateway-service.
  monitoring/          SNS alert topic, Aurora CPU alarms, API Gateway 5xx alarm.
environments/
  dev/, staging/, prod/  Root modules composing the above, one per environment.
.github/workflows/terraform.yml   fmt/validate/tfsec on PRs, plan on PRs, apply on merge to main.
```

## Choices worth knowing about (the "future-proof" part)

- **State locking without DynamoDB.** Terraform >= 1.10's S3 backend
  supports native locking (`use_lockfile = true`) - one less resource
  (a DynamoDB table) to provision, pay for, and keep in sync with the state
  bucket. `bootstrap/` only creates the bucket.
- **OIDC instead of long-lived AWS keys in CI.** `bootstrap/oidc.tf` sets up
  a GitHub Actions OIDC trust so the pipeline assumes an AWS role with
  short-lived credentials per run - no `AWS_ACCESS_KEY_ID` sitting in repo
  secrets to leak or rotate.
- **Serverless-first compute for Kafka and Postgres.** MSK Serverless and
  Aurora Serverless v2 instead of provisioned clusters: no broker
  count/instance-type/EBS sizing to guess (and re-guess) while the product's
  traffic shape is still unknown. Trades a small per-request cost premium
  for zero capacity planning.
- **RDS-managed master password.** `manage_master_user_password = true`
  means the Aurora master password is generated and rotated by AWS in
  Secrets Manager - it never appears in a `.tf`/`.tfvars` file, plan output,
  or a human's clipboard.
- **Evidence immutability is enforced twice.** S3 Object Lock in
  COMPLIANCE mode (not even the account root can delete or shorten
  retention) plus an explicit deny-delete bucket policy as a second,
  independent barrier - matches the plan's "immutable audit logs"
  principle.
- **Multi-tenancy starts at the identity layer.** Cognito's user pool
  carries a `custom:customer_id` attribute, so it's in the JWT from the
  first login, not bolted on later - matches the plan's "multi-tenant from
  day 1" principle.

## One deviation from the master plan worth flagging

The plan's tech stack names **Jenkins** for CI. This repo ships a
**GitHub Actions** workflow instead (`.github/workflows/terraform.yml`),
because it gets OIDC-based AWS auth and PR-triggered plan/validate for
free without standing up and patching a Jenkins server. If you're already
running Jenkins elsewhere and want parity, swapping this workflow for a
`ci/Jenkinsfile` (as the plan's repo structure names it) using the same
OIDC role is a straightforward port - flagging this now rather than
silently picking one for you.

## Getting started

Requires Terraform >= 1.10, an AWS account, and credentials with enough
privilege to create the bootstrap resources (only needed once, by a human).

1. **Bootstrap** (once per AWS account, applied by hand with local state):

   ```bash
   cd bootstrap
   terraform init
   terraform apply \
     -var="state_bucket_name=auditflow-tfstate-<something-globally-unique>" \
     -var="github_org=<your-github-org>"
   ```

   Save the `github_actions_role_arn` output - set it as the `AWS_ROLE_ARN`
   repo/environment variable in GitHub (Settings > Secrets and variables >
   Actions > Variables), alongside `AWS_REGION` and `TF_STATE_BUCKET`
   (the `state_bucket_name` you chose above).

   Back up `bootstrap/terraform.tfstate` somewhere durable (it's the one
   piece of state that isn't remote) - losing it just means re-importing
   the state bucket and OIDC role, not losing any data.

2. **Per environment** (`dev`, `staging`, or `prod`):

   ```bash
   cd environments/dev
   cp backend.hcl.example backend.hcl   # fill in the bucket name from step 1
   terraform init -backend-config=backend.hcl
   # Edit terraform.tfvars: evidence_bucket_name and cognito_domain_prefix
   # must be globally unique - the "changeme" placeholders will fail to apply.
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```

## Open questions / not done here

- ~~No compute target for `api-gateway`'s integration~~ **Resolved: ECS
  Fargate** (`modules/ecs` + a VPC link in `modules/api-gateway`), gated
  behind `ecs_enabled` per environment. Rollout order: apply (creates the
  ECR repos), run the **Deploy** workflow in `auditflow-platform` to push
  images, flip `ecs_enabled = true` in the environment's tfvars, apply
  again. Fargate + the internal ALB bill from that second apply onward;
  the app services' `aws` Spring profile handles MSK IAM auth and the
  RDS-managed Aurora credentials.
- **IAM policy on the GitHub Actions role is service-scoped, not
  resource-scoped** (`resources = ["*"]` per allowed service). Tightening
  this to specific ARNs is easiest once the first `apply` has produced real
  resource IDs to scope to.
- **No WAF / CloudFront in front of API Gateway yet** - worth adding before
  this is customer-facing.
- **Single-region.** No cross-region DR/replication for the evidence bucket
  or Aurora - a reasonable phase-5-or-later addition once there's a
  customer whose contract requires it.
- Compliance-controls-as-YAML (`shared/compliance-controls/*.yaml` in the
  plan) lives in the app repo's roadmap, not here.
