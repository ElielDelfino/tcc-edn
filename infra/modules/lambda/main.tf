# Empacota o código da função (backend/contador) em um zip a cada plan.
# source_code_hash muda quando o código muda, o que dispara o update da função.
data "archive_file" "code" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.build/${var.function_name}.zip"

  # Bytecode local mudaria o hash entre máquinas e geraria updates falsos da função.
  excludes = ["**/__pycache__/**", "**/*.pyc"]
}

# Log group explícito: define a retenção (sem ela os logs ficam para sempre e
# acumulam custo) e permite restringir a permissão de escrita da função a ele.
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "this" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Equivalente à AWSLambdaBasicExecutionRole, mas restrito ao log group da função.
resource "aws_iam_role_policy" "logs" {
  name = "logs"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.this.arn}:*"
    }]
  })
}

# Menor privilégio: só as duas ações usadas pelo handler, só na tabela do contador.
# Criada apenas quando a tabela existir. O count usa o NOME (conhecido no plan),
# não o ARN — o ARN só é conhecido após o apply e quebraria o count.
resource "aws_iam_role_policy" "dynamodb" {
  count = var.table_name != "" ? 1 : 0

  name = "dynamodb-counter"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:UpdateItem", "dynamodb:GetItem"]
      Resource = var.table_arn
    }]
  })
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn

  runtime = "python3.13"
  # Graviton (arm64) custa ~20% menos por GB-s; o código não tem dependências nativas.
  architectures = ["arm64"]
  handler       = "handler.lambda_handler"

  filename         = data.archive_file.code.output_path
  source_code_hash = data.archive_file.code.output_base64sha256

  memory_size = var.memory_mb
  timeout     = var.timeout_s

  environment {
    variables = {
      TABLE_NAME     = var.table_name
      COUNTER_ID     = var.counter_id
      ALLOWED_ORIGIN = var.allowed_origin
    }
  }

  # Garante que o log group (com retenção) e a permissão de log existam antes
  # da primeira invocação — senão a Lambda criaria um log group sem retenção.
  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.logs,
  ]
}
