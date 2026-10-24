# Arquitetura da Solução

![Diagrama de arquitetura do Contador de Acessos](arquitetura.svg)

Fluxo passo a passo (animado): [fluxo-contador.gif](fluxo-contador.gif)

## Fluxo Principal

```
Usuário (Browser/App)
        │
        ▼
┌─────────────────┐
│  API Gateway     │  ← HTTPS endpoint (REST API)
│  POST /count     │     Recebe a requisição
│  GET  /count     │     Retorna o total
└────────┬────────┘
         │ (invoca)
         ▼
┌─────────────────┐
│  AWS Lambda      │  ← Função serverless
│  (Python/TS)     │     Lógica: incrementa ou lê
└────────┬────────┘
         │ (UpdateItem / GetItem)
         ▼
┌─────────────────┐
│  DynamoDB        │  ← Tabela: AccessCounter
│  PK: id = "hits" │     Atributo: count (N)
│  Attr: count     │
└─────────────────┘
```

## Serviços e Justificativas

| Serviço | O que faz | Por que foi escolhido | Alternativas consideradas |
|---------|-----------|----------------------|--------------------------|
| **API Gateway** | Recebe requisições HTTP, roteia para Lambda | Managed, escala automaticamente, cobra por requisição | ALB (mais caro para baixo volume), AppSync (GraphQL desnecessário) |
| **Lambda** | Executa lógica de incremento/leitura | Serverless, paga só quando executa, escala de 0 a milhões | EC2 (custo fixo), Fargate (overhead para função simples) |
| **DynamoDB** | Armazena contador | Latência < 10ms, serverless, escala automática (on-demand) | RDS (overhead relacional), ElastiCache (volátil) |
| **IAM** | Controla permissões entre serviços | Obrigatório na AWS, princípio do menor privilégio | N/A |

## Endpoints da API

| Método | Rota | Ação | Resposta |
|--------|------|------|----------|
| `POST` | `/count` | Incrementa o contador em +1 | `{"count": 42}` |
| `GET` | `/count` | Retorna o valor atual | `{"count": 42}` |

## Schema do DynamoDB

```json
{
  "TableName": "AccessCounter",
  "KeySchema": [
    { "AttributeName": "id", "KeyType": "HASH" }
  ],
  "AttributeDefinitions": [
    { "AttributeName": "id", "AttributeType": "S" }
  ],
  "BillingMode": "PAY_PER_REQUEST"
}
```

**Item armazenado:**
```json
{
  "id": { "S": "hits" },
  "count": { "N": "42" }
}
```

## Segurança

- **IAM Role da Lambda:** Somente `dynamodb:UpdateItem` e `dynamodb:GetItem` na tabela específica (ARN exato, não `*`)
- **API Gateway:** Endpoint público (sem auth — é um contador de acesso público)
- **DynamoDB:** Encryption at rest habilitada (padrão com chave gerenciada AWS)
- **Sem VPC:** Todos os serviços são serverless e se comunicam via endpoints AWS — VPC adicionaria latência sem benefício

## Escalabilidade

| Serviço | Como escala | Limite prático |
|---------|------------|---------------|
| API Gateway | Automático | 10.000 req/s (soft limit, aumentável) |
| Lambda | Concorrência automática | 1.000 execuções simultâneas (padrão, aumentável) |
| DynamoDB (On-Demand) | Automático | Virtualmente ilimitado |

## Estimativa de Custos (região us-east-1)

> **Revisada em 2026-10-23.** A versão anterior não incluía observabilidade e usava o preço
> antigo do DynamoDB on-demand (US$ 1,25 por milhão de gravações; hoje é US$ 0,625).
> A estimativa formal com o AWS Pricing Calculator continua sendo a task 5.3 (M5).

### Premissas

- **1 acesso = 1 `POST /count`**: 1 requisição no API Gateway, 1 invocação da Lambda e
  1 gravação no DynamoDB (item < 1 KB).
- **Lambda:** 128 MB (0,125 GB), arm64, **~30 ms** por execução. É uma suposição; medir com a
  linha `REPORT` dos logs depois do deploy.
- **Logs por acesso:** ~0,35 KB da Lambda (`START`/`END`/`REPORT`) + ~0,25 KB do access log do
  API Gateway ≈ **0,6 KB**.
- **Retenção de 14 dias** (logs) e um único item na tabela: armazenamento desprezível.

### Preços de referência

| Item | Preço (us-east-1) | Cota gratuita permanente |
|---|---|---|
| API Gateway REST | US$ 3,50 / milhão de requisições ⚠️ conferir | Não (só o free tier de 12 meses de contas antigas) |
| Lambda: requisições | US$ 0,20 / milhão ⚠️ conferir | 1 milhão/mês |
| Lambda: duração arm64 | US$ 0,0000133334 / GB-s | 400 mil GB-s/mês |
| DynamoDB on-demand: gravação | US$ 0,625 / milhão de WRU | — |
| DynamoDB on-demand: leitura | US$ 0,125 / milhão de RRU | — |
| DynamoDB: armazenamento / PITR | US$ 0,25 / GB-mês / US$ 0,20 / GB-mês | 25 GB de armazenamento |
| CloudWatch Logs: ingestão (Lambda e API Gateway) | US$ 0,50 / GB (primeiros 10 TB) | 5 GB/mês (ingestão + armazenamento + Logs Insights) |
| CloudWatch Logs: armazenamento | US$ 0,03 / GB-mês | (na cota acima) |
| CloudWatch: dashboard | US$ 3,00 / dashboard / mês | 3 dashboards |
| CloudWatch: alarme (resolução padrão) | US$ 0,10 / alarme / mês | 10 alarmes |
| SNS: notificações por e-mail | US$ 2,00 / 100 mil | 1.000 e-mails/mês |
| S3: bucket do state | ~US$ 0,023 / GB-mês | — (o state tem poucos KB) |

### Custos variáveis (crescem com o tráfego)

| Cenário | API Gateway | Lambda | DynamoDB | CloudWatch Logs | Variável/mês |
|---|---|---|---|---|---|
| 100 acessos/mês | ~$0.00 | ~$0.00 | ~$0.00 | ~$0.00 | **~$0.00** |
| 10.000 acessos/mês | ~$0.04 | ~$0.00 | ~$0.01 | ~$0.00 | **~$0.05** |
| 1.000.000 acessos/mês | ~$3.50 | ~$0.25 | ~$0.63 | ~$0.29 | **~$4.66** |

Valores **sem** cotas gratuitas. A 1 milhão de acessos: Lambda = $0,20 (requisições) + ~$0,05
(3.750 GB-s), e logs = ~0,57 GB × $0,50.

### Custos fixos (não dependem do tráfego) — observabilidade

| Item | Quantidade | Sem cota gratuita | Com cota gratuita |
|---|---|---|---|
| Dashboard | 1 | $3.00 | $0.00 (se a conta tiver ≤ 3 dashboards) |
| Alarme `5XXError` | 1 | $0.10 | $0.00 (se a conta tiver ≤ 10 alarmes) |
| SNS (tópico + e-mails) | poucos e-mails | ~$0.00 | $0.00 |
| PITR + state no S3 | KBs | ~$0.00 | ~$0.00 |
| **Fixo/mês** | | **~$3.10** | **~$0.00** |

### Total por cenário

| Cenário | Usando as cotas gratuitas permanentes | Sem nenhuma cota gratuita |
|---|---|---|
| 100 acessos/mês | **~$0.00** | **~$3.10** |
| 10.000 acessos/mês | **~$0.04** | **~$3.15** |
| 1.000.000 acessos/mês | **~$4.13** (API Gateway $3,50 + DynamoDB $0,63) | **~$7.76** |

**Leitura dos números:**

- O **API Gateway é o maior custo variável** (~75% a 1 milhão de acessos). Trocar REST API por
  HTTP API reduziria esse item, mas perderia o throttling por stage.
- O **dashboard é o maior custo fixo**: US$ 3,00/mês **mesmo sem nenhum acesso**, se a conta já
  usar as 3 cotas gratuitas. Em volume baixo, ele pode custar mais que toda a aplicação.
- A observabilidade inteira (logs + dashboard + alarme + SNS) fica **dentro das cotas gratuitas**
  em uma conta dedicada ao TCC, com até ~8 milhões de acessos/mês (limite de 5 GB de logs).
- Contas AWS criadas a partir de julho de 2025 usam um novo modelo de free tier, com créditos.
  As cotas "permanentes" acima continuam valendo, mas confirme no console da conta.

> Valores aproximados, calculados a partir dos preços públicos de us-east-1. Usar o AWS Pricing
> Calculator para a estimativa formal (task 5.3).
