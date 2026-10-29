data "aws_caller_identity" "current" {}

locals {
  # O nome do bucket é único no mundo todo, então leva o ID da conta no final.
  # O trecho "-frontend-" é obrigatório: a policy da pipeline só libera buckets
  # que casam com contador-acessos-*-frontend-*.
  bucket_name = "${var.name_prefix}-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name

  # Em dev, o destroy precisa conseguir apagar o bucket mesmo com arquivos dentro.
  force_destroy = true
}

# Liberamos só a política pública (necessária para o site). ACLs públicas continuam bloqueadas.
resource "aws_s3_bucket_public_access_block" "site" {
  # checkov:skip=CKV_AWS_54: site estático público, só GetObject
  # checkov:skip=CKV_AWS_56: site estático público, só GetObject
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# Transforma o bucket em site: define a página inicial e a de erro.
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Leitura pública somente dos objetos (GetObject). Nenhuma permissão de escrita ou listagem.
data "aws_iam_policy_document" "public_read" {
  statement {
    sid       = "PublicReadSite"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.public_read.json

  # A policy pública só é aceita depois que o bloqueio de política pública é desligado.
  depends_on = [aws_s3_bucket_public_access_block.site]
}
