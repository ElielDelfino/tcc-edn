# Módulo: dynamodb

Provisiona a tabela do Amazon DynamoDB utilizada para o armazenamento do contador de acessos.

## Recursos criados

| Recurso | Descrição |
|---|---|
| `aws_dynamodb_table` | Tabela com chave de partição `id` (S) e modo de cobrança `PAY_PER_REQUEST` |

## Propósito

Armazena o total de hits do sistema de forma persistente e resiliente:

- **Incrementos Atômicos:** Projetada para operar com a expressão `ADD` do DynamoDB, garantindo que múltiplos acessos simultâneos não causem perda de contagem (race conditions).
- **Segurança:** Utiliza criptografia em repouso via **chave de propriedade da AWS (AES-256)**. Detalhes sobre a escolha desta estratégia podem ser encontrados em [docs/decisao-criptografia-dynamodb.md](../../docs/decisao-criptografia-dynamodb.md).
- **Resiliência:** Possui o Point-in-Time Recovery (PITR) ativado, permitindo a recuperação de dados de qualquer momento nos últimos 35 dias.

## Variáveis

| Nome | Tipo | Padrão | Descrição |
|---|---|---|---|
| `name_prefix` | string | — | Prefixo utilizado para nomear a tabela e garantir a governança do ambiente |

## Outputs

| Nome | Descrição |
|---|---|
| `table_name` | Nome final da tabela criada |
| `table_arn` | Amazon Resource Name (ARN) da tabela, utilizado para permissões IAM da Lambda |

## Exemplo de uso

```hcl
module "dynamodb" {
  source      = "./modules/dynamodb"
  name_prefix = "meu-projeto-dev"
}

# Consumindo os outputs para a Lambda
module "lambda" {
  source     = "./modules/lambda"
  table_name = module.dynamodb.table_name
  table_arn  = module.dynamodb.table_arn
  # ... demais variáveis
}
```

---
**Verificações:**
- Modo On-Demand configurado para otimização de custo.
- PITR ativado para recuperação de desastres.
- Integração de outputs validada com o módulo de Lambda.
