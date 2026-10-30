# Módulo: observability — guia de implementação (M6)

> **Status:** módulo **em branco**. `main.tf`, `variables.tf` e `outputs.tf` existem, mas estão
> vazios. Este guia descreve o que implementar para o monitoramento do contador.
>
> **Responsável:** M6 (Demonstração e Diferenciais). Tasks 6.3 (dashboard), 6.4 (alarme) e
> 6.8 (access logs do API Gateway) do [backlog](../../../docs/backlog.md).

> **Versão interativa:** as mesmas lições, com quiz e cartões de revisão, estão no artefato Claude do M6
> (<https://claude.ai/artifact/BngFLmqDmkytPenpKCtBtz>; peça acesso ao M2). Este arquivo é a consulta.

## O que criar e onde

Os três arquivos do módulo **já existem vazios**. Você preenche os marcados com "escreve" e edita
os marcados com "edita".

```
TCC-EdN-AWS/
├── infra/
│   ├── main.tf                        # edita: bloco module "observability" e o TODO(M6) em locals (seção 5)
│   ├── output.tf                      # edita: output dashboard_name (seção 5)
│   ├── variables.tf                   # já tem alarm_email e log_retention_days (não mexer)
│   └── modules/
│       └── observability/
│           ├── main.tf                # escreve: log group, role, SNS, alarme, dashboard (seção 1)
│           ├── variables.tf           # escreve: os 8 inputs (seção 3)
│           ├── outputs.tf             # escreve: access_log_group_arn, dashboard_name, sns_topic_arn (seção 4)
│           └── README.md              # este guia (no fim, troque pela documentação do módulo)
├── .github/workflows/terraform.yml    # NÃO é seu: o M3 mexe aqui (testes e scanner). Leia a seção 7
└── docs/arquitetura.md                # edita: registre o aviso 3 (aws_api_gateway_account vale para a conta inteira)
```

---

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

> **IAM da pipeline não é com você.** As permissões para criar tudo isto (logs, role do API Gateway,
> SNS, alarme e dashboard) estão em `boot-strap/policy_project.tf`, sob responsabilidade do M2, e já estão
> prontas. Você **não edita** a pasta `boot-strap/`. Só precisa respeitar o prefixo `contador-acessos-*`
> nos nomes (aviso 5). Se um `AccessDenied` aparecer na demo, avise o M2.

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
   apagadas** pelo `destroy`. Segundo a [documentação do SNS](https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html),
   as não confirmadas são excluídas pelo próprio SNS após **48 horas**: confirme logo depois do apply.
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

> **Já testado, sem AWS.** Uma implementação mínima seguindo este guia foi escrita numa cópia
> e passou em `terraform fmt`, `terraform init -backend=false` e `terraform validate`, com o
> módulo ligado na raiz (sem ciclo de dependência). O `checkov` rodou sobre ela (seção 7). O
> `plan` **não** foi executado, porque exige o bootstrap aplicado na AWS, e isso só vai
> acontecer no teste e na apresentação.

## 6. Validar

### Localmente (sem AWS e sem custo)

```bash
cd infra
terraform fmt -recursive
terraform init -backend=false     # não usa o bucket de state, então não precisa de credenciais
terraform validate
```

> **Não rode `terraform plan` nem `apply` por enquanto.** O `plan` precisa do bucket de state e
> de credenciais, e o bootstrap ainda não foi aplicado (isso gera custo). Quando a AWS estiver
> ligada, o `plan` deve mostrar:
>
> - `module.observability.*`: log group, role, attachment, `aws_api_gateway_account`, tópico,
>   assinatura, alarme e dashboard **will be created**;
> - `module.api_gateway.aws_api_gateway_stage.this` **will be updated in-place**, com
>   `access_log_settings`.

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
devolve `500`. Basta enviar 5 ou mais `POST` em sequência com `curl` (a página de demo hospedada no S3 será
feita pelo M7, ver `docs/guia-frontend-s3.md`).

## 7. O que mudou na pipeline (testes, scanner e S3)

O M3 vai acrescentar testes da Lambda e um scanner de IaC (checkov) ao workflow, e o M7 vai
acrescentar o site no S3. Isso afeta o seu PR assim:

1. **Seu código passa pelo checkov.** O job `iac-scan` lê o `infra/` inteiro, inclusive o seu
   módulo. Ele **avisa e não bloqueia** (só o PITR do DynamoDB, `CKV_AWS_28`, bloqueia). Rodei o
   checkov numa implementação de exemplo deste guia: **7 passam, 3 falham**:

   | ID | O que cobra | Decisão sugerida |
   |---|---|---|
   | `CKV_AWS_158` | Log group criptografado com KMS | Aceitar: logs sem dado pessoal (RNF-09), mesma lógica da decisão de criptografia do DynamoDB |
   | `CKV_AWS_338` | Retenção de logs ≥ 1 ano | Aceitar: 14 dias bastam para a demo e custam menos |
   | `CKV_AWS_26` | Tópico SNS criptografado | Aceitar: o tópico só carrega o aviso do alarme |

   Para aceitar, escreva dentro do resource, com o motivo:
   `# checkov:skip=CKV_AWS_338: 14 dias bastam para a demonstração`. Combine as decisões com o M3 e o M2.
2. **O `apply` agora depende dos testes e do scanner.** O job `apply` passa a exigir
   `backend-check` e `iac-scan` verdes. Se um teste da Lambda quebrar, o seu alarme também não vai
   ao ar. É proposital.
3. **Nada muda nos seus recursos por causa do S3.** O site (módulo `frontend`, do M7) é outro
   módulo com outro prefixo. O dashboard não precisa de widget para ele: monitorar o site no S3 está
   fora do escopo das tasks 6.3 a 6.8. Os totais de recursos citados em planos antigos
   (18 + 8) vão aumentar quando o módulo `frontend` entrar; use só o número **do seu módulo**.
4. **O `terraform fmt -check -recursive` roda na raiz do repositório**, então também confere o
   módulo do M7 e o seu. Rode `terraform fmt -recursive` antes do commit.

## 8. Checklist do PR

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
- [ ] `terraform fmt -check -recursive`, `init -backend=false` e `validate` sem erros (sem `plan`: o bootstrap não foi aplicado)
- [ ] Falhas do checkov decididas: `checkov:skip` com motivo ou correção (seção 7)
- [ ] Evidências para o slide 14: print do dashboard, alarme em `ALARM` e e-mail recebido
- [ ] Este README atualizado: troque o guia pela documentação do módulo, no mesmo formato dos
      módulos `lambda` e `api-gateway`
