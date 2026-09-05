# Lets GitHub Actions assume an AWS role via short-lived OIDC tokens instead
# of long-lived access keys stored as repo secrets - removes an entire class
# of credential-leak risk and is the direction AWS/GitHub both steer CI/CD
# integrations towards.

# The OIDC provider is account-wide, not per-repo: its URL is the identity,
# and AWS allows exactly one per account. Both this repo's bootstrap and the
# other one used to create it unconditionally, so whichever was applied
# second failed with EntityAlreadyExists - and the fix under time pressure
# (delete it, re-apply) breaks CI for the repo that owned it.
#
# So one bootstrap creates it and the other reads it. The flag says which
# this is. auditflow-infrastructure creates it; Resistance sets
# create_oidc_provider = false. Either way local.oidc_provider_arn is the
# same ARN, so the trust policies below do not care which.

data "tls_certificate" "github_actions" {
  count = var.create_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions[0].certificates[0].sha1_fingerprint]
}

data "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://token.actions.githubusercontent.com"
}

# An already-applied bootstrap has the provider at the un-indexed address.
# Without this it would be destroyed and recreated, which breaks every
# other role in the account that trusts it.
moved {
  from = aws_iam_openid_connect_provider.github_actions
  to   = aws_iam_openid_connect_provider.github_actions[0]
}

locals {
  # Exactly one of the two counts above is 1, so exactly one of these is a
  # single-element list and the other is empty. one() gives null for the
  # empty one and coalesce takes whichever is real.
  oidc_provider_arn = coalesce(
    one(aws_iam_openid_connect_provider.github_actions[*].arn),
    one(data.aws_iam_openid_connect_provider.github_actions[*].arn),
  )
}

locals {
  # Two axes of variation in GitHub's OIDC subject:
  # - Jobs bound to a GitHub Environment present `environment:<name>`
  #   instead of the ref/pull_request forms.
  # - GitHub's immutable-reference format appends "@<numeric id>" to the
  #   owner and repo segments (e.g. repo:org@123/name@456:...), so each
  #   pattern needs a classic and an @-suffixed variant.
  github_subjects = flatten([
    for repo in var.github_repos : [
      "repo:${var.github_org}/${repo}:ref:refs/heads/main",
      "repo:${var.github_org}/${repo}:pull_request",
      "repo:${var.github_org}/${repo}:environment:*",
      "repo:${var.github_org}@*/${repo}@*:ref:refs/heads/main",
      "repo:${var.github_org}@*/${repo}@*:pull_request",
      "repo:${var.github_org}@*/${repo}@*:environment:*",
    ]
  ])
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_subjects
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "auditflow-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# Scoped to the AWS services this platform actually uses. Resource-level
# scoping (rather than "*") is a natural next step once bucket/cluster ARNs
# are known post-first-apply - tracked in README's open questions.
data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid    = "PlatformServices"
    effect = "Allow"
    actions = [
      "s3:*",
      "ecs:*",
      "ecr:*",
      "elasticloadbalancing:*",
      "kafka:*",
      "rds:*",
      "glue:*",
      "athena:*",
      "emr-serverless:*",
      "apigateway:*",
      "cognito-idp:*",
      "kms:*",
      "logs:*",
      "cloudwatch:*",
      "sns:*",
      "ec2:*",
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreateServiceLinkedRole",
      "iam:PassRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "auditflow-platform-services"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}
