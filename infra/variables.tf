variable "aws_region" {
  type        = string
  description = "Região AWS dos recursos"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto — primeira parte do nome de todos os recursos"
  default     = "contador-acessos"
}

variable "environment" {
  type        = string
  description = "Ambiente — usado no nome dos recursos e como stage do API Gateway"
  default     = "dev"
}

variable "allowed_origin" {
  type        = string
  description = "Origem permitida no CORS. Em produção, usar o domínio da página"
  default     = "*"
}

variable "throttle_rate_limit" {
  type        = number
  description = "Requisições por segundo em regime contínuo no stage da API"
  default     = 50
}

variable "throttle_burst_limit" {
  type        = number
  description = "Pico momentâneo de requisições aceito pelo stage da API"
  default     = 100
}

variable "log_retention_days" {
  type        = number
  description = "Retenção dos logs da Lambda no CloudWatch (dias)"
  default     = 14
}

variable "lambda_memory_mb" {
  type        = number
  description = "Memória da função Lambda (MB)"
  default     = 128
}

variable "lambda_timeout_s" {
  type        = number
  description = "Timeout da função Lambda (segundos)"
  default     = 5
}
