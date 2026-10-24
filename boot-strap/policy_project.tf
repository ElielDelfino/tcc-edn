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
          # Configuração da conta: role que o API Gateway usa para gravar access logs.
          "arn:aws:apigateway:${var.aws_region}::/account",
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
          # Access logs do API Gateway (módulo observability).
          "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/apigateway/${local.prefix}-*",
          "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/apigateway/${local.prefix}-*:*",
        ]
      },
      {
        Sid    = "CloudWatchProjectDashboards"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutDashboard",
          "cloudwatch:GetDashboard",
          "cloudwatch:DeleteDashboards",
        ]
        Resource = "arn:aws:cloudwatch::${local.account_id}:dashboard/${local.prefix}-*"
      },
      {
        Sid    = "CloudWatchProjectAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource",
          "cloudwatch:ListTagsForResource",
        ]
        Resource = "arn:aws:cloudwatch:${var.aws_region}:${local.account_id}:alarm:${local.prefix}-*"
      },
      {
        # Ações só de leitura que não aceitam restrição por recurso.
        Sid      = "CloudWatchDescribe"
        Effect   = "Allow"
        Action   = ["cloudwatch:DescribeAlarms", "cloudwatch:ListDashboards"]
        Resource = "*"
      },
      {
        # Tópico de notificação dos alarmes e suas assinaturas (ARN = tópico + ":<id>").
        Sid      = "SNSProjectTopics"
        Effect   = "Allow"
        Action   = ["sns:*"]
        Resource = "arn:aws:sns:${var.aws_region}:${local.account_id}:${local.prefix}-*"
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
        # Anexar policy gerenciada só é permitido para a policy de logs do API Gateway.
        Sid      = "AttachAPIGatewayLogsPolicy"
        Effect   = "Allow"
        Action   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = "arn:aws:iam::${local.account_id}:role/${local.prefix}-*"
        Condition = {
          ArnEquals = {
            "iam:PolicyARN" = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
          }
        }
      },
      {
        # Só permite entregar roles do projeto à Lambda (execução) e ao API Gateway (logs).
        Sid      = "PassProjectRoles"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${local.account_id}:role/${local.prefix}-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = ["lambda.amazonaws.com", "apigateway.amazonaws.com"]
          }
        }
      },
    ]
  })
}
