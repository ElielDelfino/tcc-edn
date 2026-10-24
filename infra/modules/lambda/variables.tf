variable "function_name" {
  type        = string
  description = "Nome da função. Também nomeia a role (<nome>-role) e o log group (/aws/lambda/<nome>)"
}

variable "source_dir" {
  type        = string
  description = "Diretório com o código da função (contém handler.py)"
}

variable "table_name" {
  type        = string
  description = "Nome da tabela DynamoDB do contador. Vazio = função sobe sem permissão no DynamoDB"
  default     = ""
}

variable "table_arn" {
  type        = string
  description = "ARN da tabela DynamoDB do contador (usado na policy da função)"
  default     = ""
}

variable "counter_id" {
  type        = string
  description = "Valor da chave de partição do item do contador"
  default     = "hits"
}

variable "allowed_origin" {
  type        = string
  description = "Origem devolvida no header Access-Control-Allow-Origin"
  default     = "*"
}

variable "memory_mb" {
  type        = number
  description = "Memória da função (MB)"
  default     = 128
}

variable "timeout_s" {
  type        = number
  description = "Timeout da função (segundos)"
  default     = 5
}

variable "log_retention_days" {
  type        = number
  description = "Retenção do log group (dias)"
  default     = 14
}
