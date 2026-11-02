variable "name_prefix" {
  type        = string
  description = "Prefixo dos recursos, por exemplo contador-acessos-dev"
}

variable "aws_region" {
  type        = string
  description = "Região dos recursos monitorados"
}

variable "api_name" {
  type        = string
  description = "Nome da REST API para as métricas do API Gateway"
}

variable "stage_name" {
  type        = string
  description = "Stage da REST API, por exemplo dev"
}

variable "lambda_function_name" {
  type        = string
  description = "Nome da função Lambda monitorada"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Nome da tabela; vazio omite widgets DynamoDB até o M4 concluir a integração"
  default     = ""
}

variable "alarm_email" {
  type        = string
  description = "Destinatário SNS; vazio cria o tópico sem assinatura"
  default     = ""
  sensitive   = true
}

variable "log_retention_days" {
  type        = number
  description = "Retenção dos access logs da API Gateway, em dias"
  default     = 14
}
