terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.resource_prefix
      Component = "boot-strap"
      ManagedBy = "terraform"
    }
  }
}

# ID da conta obtido das credenciais em uso — evita fixar o account ID no código.
data "aws_caller_identity" "current" {}
