# Módulo: lambda

Provisiona a função AWS Lambda do contador de acessos, junto com a role de execução e o log
group no CloudWatch.

## Recursos criados

| Recurso | Descrição |
|---|---|
| `archive_file` (data) | Empacota `source_dir` em `.build/<function_name>.zip` a cada plan |
| `aws_cloudwatch_log_group` | `/aws/lambda/<function_name>` com retenção configurável |
| `aws_iam_role` | Role de execução `<function_name>-role`, assumível só por `lambda.amazonaws.com` |
| `aws_iam_role_policy` (logs) | `CreateLogStream` e `PutLogEvents` **somente** no log group da função |
| `aws_iam_role_policy` (dynamodb) | `UpdateItem` e `GetItem` **somente** na tabela do contador. É criada apenas quando `table_name` não está vazio |
| `aws_lambda_function` | Python 3.13, arm64, handler `handler.lambda_handler` |

## Propósito

Executa a lógica do contador (`backend/contador/handler.py`):

- `POST /count` incrementa o contador de forma atômica (`UpdateItem` com `ADD`).
- `GET /count` lê o total (`GetItem` com leitura consistente).

A função recebe a configuração por variáveis de ambiente:

| Variável | Origem |
|---|---|
| `TABLE_NAME` | `var.table_name` |
| `COUNTER_ID` | `var.counter_id` (padrão `hits`) |
| `ALLOWED_ORIGIN` | `var.allowed_origin` |

## Decisões

- **Sem `AWSLambdaBasicExecutionRole`.** A policy gerenciada permite escrever em qualquer
  log group da conta; a policy inline daqui restringe a escrita ao log group da própria função.
- **O `count` da policy do DynamoDB usa `table_name`, e não `table_arn`.** O ARN só é
  conhecido depois do apply da tabela, e o Terraform exige um valor de `count` conhecido no plan.
- **arm64 (Graviton).** Custa cerca de 20% menos por GB-s e funciona porque o código não tem
  dependências nativas.
- **`depends_on` no log group.** Sem ele, uma invocação antes da criação do log group faria a
  Lambda criar um log group próprio, sem retenção.

> **Enquanto o módulo `dynamodb` estiver vazio:** `table_name = ""`, então a policy do
> DynamoDB não é criada e as chamadas à API retornam `500` (o handler registra o erro no
> CloudWatch). Isso é esperado até a tabela existir.

## Variáveis

| Nome | Tipo | Padrão | Descrição |
|---|---|---|---|
| `function_name` | string | — | Nome da função. Também nomeia a role e o log group |
| `source_dir` | string | — | Diretório com o `handler.py` |
| `table_name` | string | `""` | Nome da tabela DynamoDB |
| `table_arn` | string | `""` | ARN da tabela (usado na policy) |
| `counter_id` | string | `"hits"` | Chave de partição do item do contador |
| `allowed_origin` | string | `"*"` | Header `Access-Control-Allow-Origin` |
| `memory_mb` | number | `128` | Memória (MB) |
| `timeout_s` | number | `5` | Timeout (s) |
| `log_retention_days` | number | `14` | Retenção dos logs (dias) |

## Outputs

| Nome | Descrição |
|---|---|
| `function_name` | Nome da função |
| `function_arn` | ARN da função |
| `invoke_arn` | ARN de invocação, usado pelo API Gateway |
| `log_group_name` | Log group no CloudWatch |
| `role_name` | Nome da role de execução |
