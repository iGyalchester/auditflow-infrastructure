# CLAUDE.md — AuditFlow Infrastructure

## What this is

Terraform for AuditFlow's AWS footprint — companion to the
**`auditflow-platform`** application repo. Layout: hand-applied
`bootstrap/` (state bucket with native S3 locking — no DynamoDB — plus a
GitHub-OIDC deploy role), 11 reusable `modules/`, and `dev` / `staging` /
`prod` root modules under `environments/`. CI
(`.github/workflows/terraform.yml`): fmt/validate/tfsec + plan on PRs,
auto-apply **dev only** on push to main; staging/prod apply and all
destroys are manual `workflow_dispatch` only.

## Owner context

- Owner: **Boris Gerard** (GitHub `iGyalchester`). Associate Software
  Engineer at JPMorganChase through Aug 2026; AWS Cloud Practitioner;
  IBM ODM V8.10 Developer certified. Part of his three-repo portfolio
  ("my stack") with `auditflow-platform` and `Resistance`.
- His workflow preference across repos: small branches + PRs that **he
  merges himself** (never merge or approve for him).

## Invariants — do not weaken these

- **Evidence bucket immutability is the product.** S3 Object Lock in
  COMPLIANCE mode (90 days dev / 7 years prod) + explicit deny-delete
  bucket policy + `prevent_destroy`. Never loosen retention, switch to
  GOVERNANCE mode, or remove the policy to make a plan/destroy easier —
  the destroy workflow deliberately retains the bucket and KMS key.
- **No long-lived AWS keys.** CI authenticates via the GitHub OIDC role
  from `bootstrap/oidc.tf`; never introduce `AWS_ACCESS_KEY_ID` secrets.
- **Secrets stay out of the repo.** Aurora uses
  `manage_master_user_password` (Secrets Manager); `backend.hcl` is
  gitignored and generated in CI from repo variables.
- Multi-tenancy rides in the JWT: Cognito's immutable
  `custom:customer_id` attribute — keep it flowing through the API
  Gateway authorizer and access logs.

## Open items (known, tracked in README)

- **Compute target: resolved — ECS Fargate** (`modules/ecs` + `modules/ecr`
  + a VPC link in `modules/api-gateway`), gated behind `ecs_enabled` per
  environment so nothing bills until images exist and the flag is flipped.
  Rollout order is in the README; the app repo's `aws` profile handles MSK
  IAM auth, the RDS-managed Aurora secret, and the real evidence bucket.
- GitHub Actions deploy role is service-scoped (`resources = ["*"]`);
  tighten to real ARNs post-apply.
- No WAF/CloudFront in front of API Gateway; single-region (no DR).
- tfsec runs `soft_fail: true` — flip once its backlog is triaged.

## Practical notes

- Terraform >= 1.10 required (native S3 lockfile); CI pins 1.13.5.
- `terraform fmt -check -recursive` gates CI — run `terraform fmt` before
  committing.
- Environment diffs are tfvars-only by design (dev: 2 AZs, single NAT,
  0.5–2 ACU, 90-day retention; prod: 3 AZs, per-AZ NAT, 1–16 ACU, 3
  instances, 7-year retention, deletion protection). Keep new knobs as
  module variables surfaced through each environment's tfvars.
