resource "aws_dynamodb_table" "this" {
  name         = "${var.name_prefix}-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Task 4.4: Criptografia em repouso (AWS Managed Key - Custo zero/baixo)
  server_side_encryption {
    enabled = true
  }

  # Task 4.6: Recuperação de ponto no tempo (PITR)
  point_in_time_recovery {
    enabled = true
  }

  # Proteção contra exclusão desativada para ambientes de desenvolvimento, a fim de permitir a destruição via pipeline
  deletion_protection_enabled = false

  tags = {
    Module = "dynamodb"
  }
}