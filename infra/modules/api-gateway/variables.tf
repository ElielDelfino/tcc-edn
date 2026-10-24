variable "name" {
  type        = string
  description = "Nome da REST API"
}

variable "stage_name" {
  type        = string
  description = "Nome do stage (aparece na URL: /<stage>/count)"
}

variable "lambda_function_name" {
  type        = string
  description = "Nome da função Lambda integrada (usado na permissão de invocação)"
}

variable "lambda_invoke_arn" {
  type        = string
  description = "ARN de invocação da função Lambda (output invoke_arn do módulo lambda)"
}

variable "allowed_origin" {
  type        = string
  description = "Origem permitida no preflight CORS (OPTIONS)"
  default     = "*"
}

variable "throttle_rate_limit" {
  type        = number
  description = "Requisições por segundo em regime contínuo"
  default     = 50
}

variable "throttle_burst_limit" {
  type        = number
  description = "Pico momentâneo de requisições"
  default     = 100
}
