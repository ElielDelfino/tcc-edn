resource "aws_iam_role" "project_role" {
  name        = var.project_name
  description = "Assumida pelo GitHub Actions via OIDC para executar o Terraform de ${var.resource_prefix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # Apenas a branch main (jobs de plan) e o GitHub Environment de deploy
          # (jobs de apply/destroy) podem assumir a role — PRs e outras branches não.
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main",
              "repo:${var.github_owner}/${var.github_repo}:environment:${var.github_environment}",
            ]
          }
        }
      }
    ]
  })
}
