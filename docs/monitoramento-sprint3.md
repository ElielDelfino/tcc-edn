# Sprint 3 — CloudWatch Logs, Dashboard e Alarm SNS

**Origem:** `docs/jira-import.csv` linhas 31 a 33. Implementação preparada para revisão; **não aplicada na AWS**.

## O que já existia (linha 31)

- A Lambda já cria o log group `/aws/lambda/<function_name>` em `infra/modules/lambda/main.tf`.
- Retenção configurada em 14 dias; política IAM autoriza `CreateLogStream` e `PutLogEvents`.
- Não há log de invocação real no repositório. START, END e REPORT aparecem após o deploy e a primeira invocação.
- O handler atual só emite uma mensagem própria quando há exceção: `logger.exception(...)`.

Após deploy/invocação, execute no PowerShell com AWS CLI v2 e credenciais autorizadas:

```powershell
aws logs tail "/aws/lambda/contador-acessos-dev-counter" --since 30m --region us-east-1
```

Evidência da linha 31: capturar no CloudWatch os eventos START/END/REPORT de uma execução **real**, com horário e request ID. Não apresentar saídas simuladas como se fossem AWS.

## Dashboard (linha 32)

Módulo: `infra/modules/observability/main.tf`, `aws_cloudwatch_dashboard.this`.

- Padrão: últimas 24h (`-PT24H`).
- `Invocations` e `Errors` da Lambda em Sum; `Duration` em Average.
- `ConsumedReadCapacityUnits` / `ConsumedWriteCapacityUnits` do DynamoDB em Sum, **somente quando a tabela real for conectada ao módulo da raiz** (dependência M4).
- Widget extra de `5XXError` da API, útil para detectar HTTP 500 tratados pela Lambda.
- Métricas podem ficar vazias até ocorrer tráfego real.

Verificação após implantação: AWS Console → CloudWatch → Dashboards → `contador-acessos-dev-dashboard`; escolher janela 24h. Registre print e horário.

## Alarme e SNS (linha 33)

Implementação recomendada conforme guia existente do M6: **5XXError do API Gateway**, `Sum`, janela de 300 s, `GreaterThanThreshold 5` (6 ou mais respostas 5XX em 5 minutos). Tópico SNS: `contador-acessos-dev-alarms`.

**Diferença com o texto literal do Jira:** ele solicita `Lambda Errors > 5`. O handler atual captura exceções, registra a falha e devolve HTTP 500. Assim, `AWS/Lambda Errors` pode ser zero apesar de falhas do backend. O alarme HTTP 5XX protege o comportamento percebido pelo usuário, mas depende de validação da equipe para aceite da tarefa literal.

A inscrição SNS por e-mail é criada somente se `alarm_email` for informado pelo secret `ALARM_EMAIL` da pipeline; sem e-mail, o alarme existe, mas não há destinatário. A assinatura enviada pela AWS deve ser confirmada por quem recebe.

Validação do circuito **sem provocar falhas reais**:

```powershell
aws cloudwatch set-alarm-state --alarm-name contador-acessos-dev-api-5xx --state-value ALARM --state-reason "Teste controlado Sprint 3" --region us-east-1
```

Essa operação testa a transição do alarme e a entrega SNS; **não** comprova 6 erros HTTP reais. A AWS volta a avaliar o alarme a partir das métricas, possivelmente rapidamente. Capturar histórico do alarme e mensagem de e-mail. Coordenar com os responsáveis pela conta AWS antes de executar.

## Infraestrutura e dependências

- `aws_api_gateway_account` define a role de logs de **todas as APIs REST na conta e região**. Verificar alterações do plan antes do apply e alinhar com M2.
- O módulo DynamoDB continua vazio na cópia de 29/10/2026. Widgets DynamoDB só surgem depois que M4 fornecer `table_name` na raiz.
- A variável `alarm_email` é `sensitive`; não versionar destinatário, segredo nem credencial AWS.
- O arquivo `.github/workflows/terraform.yml` do ZIP original está **totalmente comentado**. Nenhum `apply` pode ser presumido como disponível a partir desse arquivo; verificar com o responsável M3 antes de implantar.
- O ZIP não comprova recursos já criados na conta AWS.

## Verificação local (sem AWS)

```powershell
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
py -3 -m pytest backend\tests -q
```

`init -backend=false` e `validate` inspecionam a configuração local, mas não provam permissões, deploy ou métricas reais. Não executar `apply` nem `destroy` sem acordo com o grupo e revisão do `plan`.

## Critérios de aceite separados

1. Logs (31): capturar evento real da função no CloudWatch.
2. Dashboard (32): publicar e capturar 24h de métricas Lambda e DynamoDB, após integração M4.
3. Alarme (33): demonstrar regra correta, SNS confirmado e recebimento de e-mail; registrar justificativa/aceite sobre a métrica API 5XX versus Lambda Errors.
