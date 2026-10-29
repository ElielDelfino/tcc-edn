terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  # Prefixo de todos os recursos. Precisa começar com o resource_prefix do
  # boot-strap, senão a role da pipeline não tem permissão para gerenciá-los.
  name_prefix = "${var.project_name}-${var.environment}"

  # TODO(M4): substituir pelos outputs do módulo quando a tabela existir:
  #   dynamodb_table_name = module.dynamodb.table_name
  #   dynamodb_table_arn  = module.dynamodb.table_arn
  # Enquanto vazios, a Lambda sobe sem permissão no DynamoDB e responde 500.
  # Guia completo em modules/dynamodb/README.md.
  dynamodb_table_name = ""
  dynamodb_table_arn  = ""

  # O módulo observability entrega o log group e a role da conta antes da ativação.
  apigw_access_log_group_arn = module.observability.access_log_group_arn
}

# -------------------------------------------------------
# DynamoDB — responsabilidade do M4 (módulo ainda vazio)
# -------------------------------------------------------
module "dynamodb" {
  source = "./modules/dynamodb"
}

# -------------------------------------------------------
# Frontend S3 — site estático da página do contador (M7)
# -------------------------------------------------------
module "frontend" {
  source      = "./modules/frontend"
  name_prefix = local.name_prefix
}

# -------------------------------------------------------
# Lambda — lógica do contador (backend/contador)
# -------------------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  function_name      = "${local.name_prefix}-counter"
  source_dir         = "${path.root}/../backend/contador"
  table_name         = local.dynamodb_table_name
  table_arn          = local.dynamodb_table_arn
  allowed_origin     = module.frontend.website_origin
  memory_mb          = var.lambda_memory_mb
  timeout_s          = var.lambda_timeout_s
  log_retention_days = var.log_retention_days
}

# -------------------------------------------------------
# API Gateway — endpoint público GET/POST /count
# -------------------------------------------------------
module "api_gateway" {
  source = "./modules/api-gateway"

  name                 = "${local.name_prefix}-api"
  stage_name           = var.environment
  lambda_function_name = module.lambda.function_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  allowed_origin       = module.frontend.website_origin
  throttle_rate_limit  = var.throttle_rate_limit
  throttle_burst_limit = var.throttle_burst_limit
  access_log_group_arn = local.apigw_access_log_group_arn
}

# -------------------------------------------------------
# Observabilidade (dashboard, alarme, access logs) — responsabilidade do M6
# (módulo ainda vazio)
# -------------------------------------------------------
module "observability" {
  source = "./modules/observability"

  name_prefix          = local.name_prefix
  aws_region           = var.aws_region
  api_name             = module.api_gateway.rest_api_name
  stage_name           = var.environment
  lambda_function_name = module.lambda.function_name
  dynamodb_table_name  = local.dynamodb_table_name
  alarm_email          = var.alarm_email
  log_retention_days   = var.log_retention_days
}
