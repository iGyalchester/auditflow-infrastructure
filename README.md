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
- **The gateway is told the client's address, not asked to guess it.** Two
  hops (this API, then the internal ALB) sit in front of the services, so
  the socket address they see is the load balancer and a per-client rate
  limit would be one global bucket. The HTTP API integration therefore sets
  `X-Client-IP` from `$context.identity.sourceIp` with an `overwrite:`
  mapping. Deliberately not `X-Forwarded-For`: every hop appends to it, so
  its leading entry is client-supplied and a caller could rotate it to
  escape the limit or forge someone else's to get them limited.
  `overwrite:` means the value is ours even if the client sent one.
- **The ALB health check asks whether the task can serve, not whether the
  database is up.** The target group probes
  `/actuator/health/liveness` on api-gateway-service and requires a 200. It
  used to probe `/`, which the enforced security chain denies, so the check
  had to accept `200-404` and passed on the 401 - meaning a wedged JVM
  counted as healthy for as long as it could still return a rejection.
  Liveness deliberately leaves Aurora out: this check is also what ECS uses
  to decide a task is dead, so wiring a shared dependency into it would let
  one Aurora blip drain every gateway task at once and trigger a
  replacement storm. A database outage should degrade responses, not delete
  the fleet.
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

## Retention, per store

| Store | Policy | Where it lives |
|---|---|---|
| S3 evidence | Object Lock, COMPLIANCE mode, `object_lock_retention_days` (365 default). **Never auto-expired**: no lifecycle rule by design, and the bucket policy denies adding one. Deletion after the lock is an explicit human act. | `modules/s3` |
| Kafka topics | `retention.ms` = 7 days, declared by the producing service on startup (MSK Serverless retention is per topic). | `auditflow-platform` ingestion/enrichment config |
| Aurora metadata | Rows older than `audit.retention.days` (400 default) purged nightly in batches by enrichment-service. Backups: `backup_retention_period` in `modules/aurora`. | `auditflow-platform` enrichment config |
| CloudWatch logs | `log_retention_days` (90 default) on the ECS log group. | `modules/ecs` |

## Ingestion tokens (ECS)

Every source that posts audit events presents an `X-Audit-Token`, and each
token is **bound to the one customer it may write as**. A token that only
authenticates would prove the caller is *a* known source and then let it
post events under any `customerId` - a forged audit trail, which is the one
thing this platform may not permit.

Create the secret by hand as a *plain string* of `tenant=token` pairs, then
name it per environment in `terraform.tfvars`:

```hcl
ingestion_tokens_secret_arn = "arn:aws:secretsmanager:...:secret:auditflow/ingestion-tokens-XXXX"
```

```
resistance=<random 32+ chars>,acme=<a different random 32+ chars>
```

Only `ingestion-service` receives it (as `AUDIT_INGESTION_TOKENS`) and only
the execution role can read it. Leaving it blank means the endpoint accepts
any `customerId` from anyone who can reach it; that is the dev default and
**staging and prod refuse to apply with `ecs_enabled = true` without it**.

## Alert notifications (ECS)

`alerting-service` sends Slack and email alerts once told where. Per
environment, in `terraform.tfvars`:

```hcl
alert_slack_webhook_secret_arn = "arn:aws:secretsmanager:...:secret:auditflow/slack-webhook-XXXX"
alert_email_from               = "alerts@your-verified-domain.example"
alert_email_to                 = "security@your-domain.example,oncall@your-domain.example"
```

Create the Slack secret by hand as a *plain string* (the webhook URL is a
credential - anyone holding it can post to the channel - so it never goes
in tfvars or environment variables). The email sender must be verified in
SES; in SES sandbox mode recipients must be verified too. Leave either
blank and that notifier logs instead of sending.

## Troubleshooting

### Bootstrap drift: `AccessDeniedException ... ecr:CreateRepository`

The Terraform workflow's OIDC role gets its permissions from
`bootstrap/oidc.tf`, which is applied **by hand** (step 1 above) - the
role cannot widen its own policy. When a later change adds a new AWS
service (ECR and ECS were added this way), the workflow fails with an
AccessDenied naming that service until the bootstrap is re-applied:

```bash
cd bootstrap
terraform apply \
  -var="state_bucket_name=<the bucket from step 1>" \
  -var="github_org=<your-github-org>"
```

Then re-run the failed workflow. Any `AccessDenied` from the workflow
whose action is in `bootstrap/oidc.tf`'s allow list is this, not a bug in
the environment configuration.

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
