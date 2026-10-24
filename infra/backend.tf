# State remoto no bucket criado pelo boot-strap/.
# O nome do bucket NÃO fica no código (backend não aceita variáveis) — é passado no init:
#   terraform init -backend-config="bucket=<s3_bucket_name>"
# Na pipeline ele vem da variable TF_STATE_BUCKET do GitHub.
terraform {
  backend "s3" {
    key          = "contador-acessos/dev.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # lock nativo do S3 (Terraform >= 1.10), sem tabela DynamoDB de lock
  }
}
