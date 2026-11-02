# Os logs da Lambda já existem em modules/lambda. Este grupo é para os
# access logs do API Gateway, sem IP e sem user-agent (RNF-09).
resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${var.name_prefix}-access"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.name_prefix}-apigw-cloudwatch"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# ATENÇÃO: configuração compartilhada por todas as REST APIs da conta/região.
# Conferir antes do apply, pois substitui a role atualmente configurada.
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
  depends_on          = [aws_iam_role_policy_attachment.api_gateway_cloudwatch]
}

resource "aws_sns_topic" "alarms" {
  name = "${var.name_prefix}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = nonsensitive(var.alarm_email != "") ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# MONITORAMENTO OPERACIONAL: o handler captura exceções e devolve HTTP 500.
# Por isso AWS/Lambda Errors pode continuar em zero enquanto a API falha.
# Este alarme mede respostas 5XX vistas pelo cliente (decisão técnica
# diferente do texto literal do Jira; validar com a equipe antes do aceite).
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.name_prefix}-api-5xx"
  alarm_description   = "Mais de 5 respostas HTTP 5XX na API REST em 5 minutos"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  dimensions          = { ApiName = var.api_name, Stage = var.stage_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold" # 6 ou mais, como no Jira (> 5)
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

locals {
  lambda_dimension = ["FunctionName", var.lambda_function_name]
  api_dimensions   = ["ApiName", var.api_name, "Stage", var.stage_name]
  dynamo_dimension = ["TableName", var.dynamodb_table_name]

  # Métricas de leitura/gravação só aparecem se a tabela estiver disponível.
  dynamodb_widgets = var.dynamodb_table_name == "" ? [] : [{
    type   = "metric"
    x      = 0
    y      = 12
    width  = 24
    height = 6
    properties = {
      title   = "DynamoDB — capacidade consumida (RCU / WCU)"
      region  = var.aws_region
      view    = "timeSeries"
      period  = 300
      stacked = false
      metrics = [
        concat(["AWS/DynamoDB", "ConsumedReadCapacityUnits"], local.dynamo_dimension, [{ stat = "Sum", label = "Leituras (RCU)" }]),
        concat(["AWS/DynamoDB", "ConsumedWriteCapacityUnits"], local.dynamo_dimension, [{ stat = "Sum", label = "Gravações (WCU)" }]),
      ]
    }
  }]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.name_prefix}-dashboard"
  dashboard_body = jsonencode({
    start          = "-PT24H" # últimas 24h por padrão no dashboard
    periodOverride = "inherit"
    widgets = concat([
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda — invocações e erros"
          region = var.aws_region
          view   = "timeSeries"
          period = 300
          metrics = [
            concat(["AWS/Lambda", "Invocations"], local.lambda_dimension, [{ stat = "Sum", label = "Invocações" }]),
            concat(["AWS/Lambda", "Errors"], local.lambda_dimension, [{ stat = "Sum", label = "Erros da função (não HTTP 500 tratado)" }]),
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda — duração média (ms)"
          region = var.aws_region
          view   = "timeSeries"
          period = 300
          metrics = [
            concat(["AWS/Lambda", "Duration"], local.lambda_dimension, [{ stat = "Average", label = "Duração média (ms)" }]),
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "API Gateway — erros 5XX (base do alarme)"
          region = var.aws_region
          view   = "timeSeries"
          period = 300
          metrics = [
            concat(["AWS/ApiGateway", "5XXError"], local.api_dimensions, [{ stat = "Sum", label = "Respostas 5XX" }]),
          ]
        }
      }
    ], local.dynamodb_widgets)
  })
}
