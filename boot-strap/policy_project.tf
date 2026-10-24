locals {
  account_id = data.aws_caller_identity.current.account_id
  prefix     = var.resource_prefix
}

# Permissões para o Terraform da pasta infra/ gerenciar a stack do projeto.
# Em vez de policies *FullAccess, cada serviço fica restrito aos recursos
# cujo nome começa com o prefixo do projeto (resource_prefix).
resource "aws_iam_role_policy" "terraform_state_and_infra" {
  name = "terraform-state-and-infra"
  role = aws_iam_role.project_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformStateBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        # Inclui o objeto <key>.tflock usado pelo lock nativo do S3 (use_lockfile).
        Sid      = "TerraformStateObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Sid      = "DynamoDBProjectTables"
        Effect   = "Allow"
        Action   = ["dynamodb:*"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.prefix}-*"
      },
      {
        Sid      = "LambdaProjectFunctions"
        Effect   = "Allow"
        Action   = ["lambda:*"]
        Resource = "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${local.prefix}-*"
      },
      {
        # IDs de REST API são gerados pela AWS, então não dá para restringir por nome.
        Sid    = "APIGateway"
        Effect = "Allow"
        Action = ["apigateway:GET", "apigateway:POST", "apigateway:PUT", "apigateway:PATCH", "apigateway:DELETE"]
        Resource = [
          "arn:aws:apigateway:${var.aws_region}::/restapis",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*",
          "arn:aws:apigateway:${var.aws_region}::/tags/*",
        ]
      },
      {
        Sid    = "CloudWatchLogsProjectGroups"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:TagResource",
          "logs:UntagResource",
          "logs:ListTagsForResource",
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-*",
          "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-*:*",
        ]
      },
      {
        # DescribeLogGroups não suporta restrição por recurso.
        Sid      = "CloudWatchLogsDescribe"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Sid    = "IAMProjectRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
        ]
        Resource = "arn:aws:iam::${local.account_id}:role/${local.prefix}-*"
      },
      {
        # Só permite entregar roles do projeto ao serviço Lambda.
        Sid      = "PassProjectRolesToLambda"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${local.account_id}:role/${local.prefix}-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      },
    ]
  })
}
