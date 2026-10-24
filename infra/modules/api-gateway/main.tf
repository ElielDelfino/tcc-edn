# REGIONAL evita a distribuição CloudFront implícita do tipo EDGE,
# desnecessária para um único endpoint consumido pela página.
resource "aws_api_gateway_rest_api" "this" {
  name        = var.name
  description = "API pública do contador de acessos da página 'Em Breve'"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "count" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "count"
}

# -------------------------------------------------------
# GET /count (consulta) e POST /count (incrementa) -> Lambda (proxy)
# -------------------------------------------------------
locals {
  lambda_methods = toset(["GET", "POST"])
}

resource "aws_api_gateway_method" "lambda" {
  for_each = local.lambda_methods

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.count.id
  http_method   = each.value
  authorization = "NONE" # contador público, sem autenticação
}

resource "aws_api_gateway_integration" "lambda" {
  for_each = local.lambda_methods

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.count.id
  http_method = aws_api_gateway_method.lambda[each.key].http_method

  # AWS_PROXY repassa a requisição inteira como evento e devolve a resposta
  # da Lambda sem transformação. A chamada à Lambda é sempre POST.
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.lambda_invoke_arn
}

# -------------------------------------------------------
# OPTIONS /count — preflight CORS respondido pelo próprio API Gateway (MOCK),
# sem invocar (nem cobrar) a Lambda. Os headers CORS de GET/POST vêm do handler.
# -------------------------------------------------------
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.count.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.count.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.count.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.count.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = aws_api_gateway_method_response.options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.allowed_origin}'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
  }

  depends_on = [aws_api_gateway_integration.options]
}

# -------------------------------------------------------
# Deployment + stage
# -------------------------------------------------------
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Um deployment é um snapshot da API: sem este trigger, mudanças em métodos
  # ou integrações não seriam publicadas no stage.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.count,
      aws_api_gateway_method.lambda,
      aws_api_gateway_integration.lambda,
      aws_api_gateway_method.options,
      aws_api_gateway_integration.options,
      aws_api_gateway_integration_response.options,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration_response.options,
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
}

# Teto de requisições do stage: o endpoint é público e sem autenticação,
# então limita o custo em caso de abuso/robôs. Excedentes recebem 429.
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit
  }
}

# Autoriza o API Gateway a invocar a função — apenas a partir de /count desta API.
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*/count"
}
