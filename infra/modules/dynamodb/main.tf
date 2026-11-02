resource "aws_dynamodb_table" "this" {
  name         = "${var.name_prefix}-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Task 4.4: Criptografia em repouso
  # Por padrão, o DynamoDB utiliza criptografia AES-256 com chaves de propriedade da AWS (AWS Owned Key)
  # Sem custo adicional e sem necessidade de configuração explícita.

  # Task 4.6: Recuperação de ponto no tempo (PITR)
  point_in_time_recovery {
    enabled = true
  }

  # Proteção contra exclusão desativada para ambientes de desenvolvimento, a fim de permitir a destruição via pipeline
  deletion_protection_enabled = false
}