# Módulo: observability — guia de implementação (M6)

> **Status:** módulo **em branco**. `main.tf`, `variables.tf` e `outputs.tf` existem, mas estão
> vazios. Este guia descreve o que implementar para o monitoramento do contador.
>
> **Responsável:** M6 (Demonstração e Diferenciais). Tasks 6.3 (dashboard), 6.4 (alarme) e
> 6.8 (access logs do API Gateway) do [backlog](../../../docs/backlog.md).

## Situação atual

**O que já existe e não precisa ser feito:**

| Item | Onde | Situação |
|---|---|---|
| Logs da Lambda (task 6.2) | `modules/lambda` | Log group `/aws/lambda/contador-acessos-dev-counter`, retenção de 14 dias, IAM restrito |
| Métricas automáticas | AWS | API Gateway (`Count`, `4XXError`, `5XXError`, `Latency`), Lambda (`Invocations`, `Duration`, `Throttles`…) e DynamoDB (quando a tabela existir). Publicadas sem configuração |
| Permissões da pipeline | `boot-strap/policy_project.tf` | **Já liberadas** para dashboard, alarme, SNS, log group de access logs e role do API Gateway |
| Gancho dos access logs | `modules/api-gateway` | O stage ativa os access logs sozinho quando recebe o ARN do log group |
| Variável do e-mail | `infra/variables.tf` → `alarm_email` | Na pipeline vem do secret opcional `ALARM_EMAIL` |

**O que falta (você):** dashboard, alarme com notificação e access logs do API Gateway.

---

## 1. O que criar em `main.tf`

### a) Access logs do API Gateway (task 6.8)

| Recurso | Configuração |
|---|---|
| `aws_cloudwatch_log_group` | Nome `"/aws/apigateway/${var.name_prefix}-access"`, `retention_in_days = var.log_retention_days` |
| `aws_iam_role` | Nome `"${var.name_prefix}-apigw-cloudwatch"`, assumível por `apigateway.amazonaws.com` |
| `aws_iam_role_policy_attachment` | Policy gerenciada `arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs`. **É a única que a pipeline pode anexar** |
| `aws_api_gateway_account` | `cloudwatch_role_arn` = ARN da role acima, com `depends_on` no attachment |

O **formato** dos logs já está definido no módulo `api-gateway`: um JSON com `requestId`,
`requestTime`, `httpMethod`, `resourcePath`, `status`, latências e `integrationStatus`. Ele
**não inclui IP nem user agent**, por causa do RNF-09. Não é preciso mexer nisso.

### b) Notificação (SNS)

| Recurso | Configuração |
|---|---|
| `aws_sns_topic` | Nome `"${var.name_prefix}-alarms"` |
| `aws_sns_topic_subscription` | `protocol = "email"`, `endpoint = var.alarm_email`, **criada só quando o e-mail não estiver vazio** (`count = var.alarm_email != "" ? 1 : 0`) |

### c) Alarme (task 6.4)

`aws_cloudwatch_metric_alarm` com nome `"${var.name_prefix}-api-5xx"`:

| Campo | Valor |
|---|---|
| `namespace` / `metric_name` | `AWS/ApiGateway` / `5XXError` |
| `dimensions` | `{ ApiName = var.api_name, Stage = var.stage_name }` |
| `statistic` / `period` / `evaluation_periods` | `Sum` / `300` / `1` → "5 erros em 5 minutos" (critério do backlog) |
| `threshold` / `comparison_operator` | `5` / `GreaterThanOrEqualToThreshold` |
| `treat_missing_data` | `notBreaching` (sem tráfego não é erro) |
| `alarm_actions` / `ok_actions` | ARN do tópico SNS |

### d) Dashboard (task 6.3)

`aws_cloudwatch_dashboard` com nome `"${var.name_prefix}-dashboard"` e `dashboard_body` em
`jsonencode(...)`. Widgets sugeridos:

| Widget | Métricas | Dimensões |
|---|---|---|
| Requisições da API | `Count`, `4XXError`, `5XXError` (`AWS/ApiGateway`) | `ApiName`, `Stage` |
| Latência da API | `Latency`, `IntegrationLatency` (p50/p99) | `ApiName`, `Stage` |
| Lambda | `Invocations`, `Duration`, `Throttles`, `ConcurrentExecutions` (`AWS/Lambda`) | `FunctionName` |
| DynamoDB | `ConsumedReadCapacityUnits`, `ConsumedWriteCapacityUnits`, `ThrottledRequests` (`AWS/DynamoDB`) | `TableName`. **Só quando `var.dynamodb_table_name != ""`**: a tabela é do M4 e pode ainda não existir |

Dica: monte o dashboard primeiro no **console** e copie o JSON em *Actions → View/edit source*.
Depois troque os valores fixos pelas variáveis.

---

## 2. ⚠️ Avisos importantes

1. **O alarme deve usar `5XXError` do API Gateway, e não `Errors` da Lambda.** O handler
   **captura** as exceções e devolve `500`, então para a Lambda a execução "deu certo" e
   `Errors` fica em **0**. Os erros aparecem em `5XXError` e nas linhas `ERROR` do log da Lambda.
2. **O output `access_log_group_arn` precisa de `depends_on = [aws_api_gateway_account.this]`.**
   Sem isso, o Terraform pode ativar os access logs no stage **antes** de a role da conta
   existir, e o apply falha com *"CloudWatch Logs role ARN must be set in account settings"*.
   Exemplo:

   ```hcl
   output "access_log_group_arn" {
     value      = aws_cloudwatch_log_group.access.arn
     depends_on = [aws_api_gateway_account.this]
   }
   ```

3. **`aws_api_gateway_account` é uma configuração única da conta, por região.** Ela vale para
   **todas** as APIs da conta. Se outro projeto na mesma conta já configurou uma role, ela será
   substituída. Na conta do TCC isso não é problema, mas registre no documento de arquitetura.
4. **A assinatura de e-mail fica pendente** até alguém clicar no link de confirmação que a AWS
   envia. Enquanto isso, o alarme não entrega notificações. Assinaturas pendentes **não são
   apagadas** pelo `destroy`: elas expiram sozinhas em 3 dias.
5. **Prefixo obrigatório.** A role da pipeline só tem permissão em recursos
   `contador-acessos-*` (dashboard, alarme, tópico, role) e `/aws/apigateway/contador-acessos-*`
   (log group). Outro nome resulta em `AccessDenied`.
6. **O e-mail é dado pessoal.** Ele **nunca** entra no código nem em `.tfvars` versionado: vem
   do secret `ALARM_EMAIL`. A variável já é `sensitive`, então não aparece nos logs do plan.

---

## 3. `variables.tf`: inputs do módulo

| Variável | Tipo | Padrão | Valor passado pela raiz |
|---|---|---|---|
| `name_prefix` | string | — | `local.name_prefix` |
| `aws_region` | string | — | `var.aws_region` |
| `api_name` | string | — | `module.api_gateway.rest_api_name` |
| `stage_name` | string | — | `var.environment` |
| `lambda_function_name` | string | — | `module.lambda.function_name` |
| `dynamodb_table_name` | string | `""` | `local.dynamodb_table_name` (vazio até o M4 terminar) |
| `alarm_email` | string, **`sensitive = true`** | `""` | `var.alarm_email` |
| `log_retention_days` | number | `14` | `var.log_retention_days` |

## 4. `outputs.tf`: outputs obrigatórios

**Use exatamente estes nomes:**

| Output | Valor | Observação |
|---|---|---|
| `access_log_group_arn` | ARN do log group dos access logs | **Com o `depends_on` do aviso 2** |
| `dashboard_name` | Nome do dashboard | Usado no output da raiz |
| `sns_topic_arn` | ARN do tópico de alarmes | — |

## 5. Ligar o módulo na raiz (`infra/main.tf` e `infra/output.tf`)

**a) Passe os inputs no bloco do módulo** (todos os valores já existem na raiz):

```hcl
module "observability" {
  source = "./modules/observability"

  name_prefix          = local.name_prefix
  aws_region           = var.aws_region
  api_name             = module.api_gateway.rest_api_name
  stage_name           = var.environment
  lambda_function_name = module.lambda.function_name
  dynamodb_table_name  = local.dynamodb_table_name
  alarm_email          = var.alarm_email
  log_retention_days   = var.log_retention_days
}
```

**b) Troque o placeholder no bloco `locals`** (há um `TODO(M6)` marcando o lugar):

```hcl
  apigw_access_log_group_arn = module.observability.access_log_group_arn
```

O módulo `api-gateway` ativa os access logs no stage automaticamente quando esse valor deixa
de ser vazio.

**c) Exponha o dashboard** em `infra/output.tf`:

```hcl
output "dashboard_name" {
  value = module.observability.dashboard_name
}
```

> **Já testado.** Uma implementação mínima seguindo este guia foi validada com `terraform plan`
> offline, sem ciclo de dependência. Com `alarm_email` preenchido, o plan cria **26 recursos**
> (os 18 atuais + 8 deste módulo), o stage passa a ter `access_log_settings` e o e-mail aparece
> só como `(sensitive value)`. Sem e-mail, são 25 recursos e nenhuma assinatura.

## 6. Validar

### Localmente

```bash
cd infra
terraform fmt -recursive
terraform init -backend-config="bucket=<TF_STATE_BUCKET>"
terraform validate
TF_VAR_alarm_email="seu-email@exemplo.com" terraform plan
```

No `plan`, confira:

- `module.observability.*`: log group, role, attachment, `aws_api_gateway_account`, tópico,
  assinatura, alarme e dashboard **will be created**;
- `module.api_gateway.aws_api_gateway_stage.this` **will be updated in-place**, com
  `access_log_settings` (com a infra já aplicada).

### Na pipeline

1. No GitHub, crie o secret **`ALARM_EMAIL`** (Settings → Secrets and variables → Actions).
2. Merge na `main` → o job de plan roda. Depois, **Actions → Terraform CI/CD → Run workflow → `apply`**.
3. **Confirme a assinatura** no e-mail recebido da AWS.

### Na demo

```bash
# Access logs chegando (faça algumas chamadas à API antes)
aws logs tail /aws/apigateway/contador-acessos-dev-access --follow

# Forçar o alarme para mostrar a notificação, sem precisar gerar erros reais
aws cloudwatch set-alarm-state \
  --alarm-name contador-acessos-dev-api-5xx \
  --state-value ALARM --state-reason "Teste da demonstração"
```

Também dá para disparar o alarme "de verdade": enquanto a tabela do M4 não existir, toda chamada
devolve `500`. Basta usar o **teste de concorrência** da página de demo (`frontend/`) com N ≥ 5.

## 7. Checklist do PR

- [ ] Nomes com prefixo `contador-acessos-<env>-…` (e log group `/aws/apigateway/contador-acessos-…`)
- [ ] Log group dos access logs com retenção
- [ ] Role do API Gateway usando **só** `AmazonAPIGatewayPushToCloudWatchLogs`
- [ ] `aws_api_gateway_account` com `depends_on` no attachment
- [ ] Output `access_log_group_arn` com `depends_on` no `aws_api_gateway_account`
- [ ] Tópico SNS e assinatura de e-mail condicionada a `alarm_email != ""`
- [ ] Alarme em `5XXError` do API Gateway (não em `Errors` da Lambda), ≥ 5 em 5 min
- [ ] Dashboard com API Gateway, Lambda e DynamoDB (este último só se houver tabela)
- [ ] Nenhum e-mail ou dado pessoal no código
- [ ] Placeholder `TODO(M6)` trocado e output `dashboard_name` adicionado
- [ ] `terraform fmt -check -recursive` e `terraform validate` sem erros
- [ ] `plan` revisado: 8 recursos novos (7 sem e-mail) e stage com `access_log_settings`
- [ ] Evidências para o slide 14: print do dashboard, alarme em `ALARM` e e-mail recebido
- [ ] Este README atualizado: troque o guia pela documentação do módulo, no mesmo formato dos
      módulos `lambda` e `api-gateway`
