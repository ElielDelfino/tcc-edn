variable "aws_region" {
  type        = string
  description = "Região AWS onde os recursos serão criados"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Nome da role IAM que será criada para o GitHub Actions"
}

variable "github_owner" {
  type        = string
  description = "Usuário ou organização do GitHub"
}

variable "github_repo" {
  type        = string
  description = "Nome do repositório do GitHub"
}

variable "github_environment" {
  type        = string
  description = "GitHub Environment usado pelos jobs de apply/destroy da pipeline"
  default     = "dev"
}

variable "s3_bucket_name" {
  type        = string
  description = "Nome do bucket S3 para armazenar o estado do Terraform (único globalmente)"
}

variable "create_oidc_provider" {
  type        = bool
  description = "Cria o OIDC provider do GitHub Actions. Use false se ele já existir na conta (só pode haver um por conta)"
  default     = true
}

variable "resource_prefix" {
  type        = string
  description = "Prefixo dos recursos da infra do projeto. A role só pode gerenciar recursos com este prefixo"
  default     = "contador-acessos"
}
