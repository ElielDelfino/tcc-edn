# TCC — Contador de Acessos Serverless na AWS

Contador de acessos para a página "Em Breve" de uma campanha de marketing, implementado
com **Amazon API Gateway + AWS Lambda + Amazon DynamoDB**, provisionado com **Terraform** e
entregue por uma pipeline de **GitHub Actions**.

![Fluxo do Contador de Acessos](docs/fluxo-contador.gif)

Diagrama estático: [docs/arquitetura.svg](docs/arquitetura.svg)

## Organização do repositório

```
.
├── .github/workflows/
│   └── terraform.yml            # CI/CD: plan no push da main; apply/destroy manuais
├── boot-strap/                  # Fundação (roda 1x, localmente): bucket de state + role OIDC do GitHub Actions
├── infra/                       # Infra do contador (Terraform, state remoto no S3)
│   ├── backend.tf · main.tf · variables.tf · output.tf
│   ├── env/dev.tfvars.example
│   └── modules/
│       ├── lambda/              # Função, role de execução e log group
│       ├── api-gateway/         # REST API GET/POST /count, CORS e throttling
│       ├── dynamodb/            # ⚠️ em branco — guia de implementação no README (M4)
│       └── observability/       # proposta IaC: dashboard, alarme SNS e access logs (revisão M6)
├── backend/
│   └── contador/handler.py      # Código da Lambda (empacotado pelo Terraform)
├── frontend/                    # (a criar pelo M7) página estática hospedada no S3. Guia: docs/guia-frontend-s3.md
└── docs/                        # Arquitetura, requisitos, backlog, handoffs...
```

O código da Lambda (`backend/`) não depende da ferramenta de IaC: o módulo `lambda` gera o
zip a partir de `backend/contador` a cada `plan`.

## Como colocar no ar

### 1. Bootstrap (uma vez, com credenciais de administrador)

Cria o bucket do state remoto, o OIDC provider do GitHub e a role que a pipeline assume.
Passo a passo em **[boot-strap/README.md](boot-strap/README.md)**.

```bash
cd boot-strap
cp terraform.tfvars.example terraform.tfvars   # ajuste os valores
terraform init && terraform apply
```

### 2. Configurar o repositório no GitHub

Em **Settings → Secrets and variables → Actions**, use os outputs do bootstrap:

| Tipo | Nome | Valor |
|---|---|---|
| Secret | `AWS_ROLE_ARN` | `project_role_arn` |
| Variable | `TF_STATE_BUCKET` | `s3_bucket_name` |
| Variable | `AWS_REGION` | `s3_bucket_region` |
| Secret (opcional) | `ALARM_EMAIL` | E-mail que recebe os alarmes do CloudWatch (vazio = sem notificação) |

Em **Settings → Environments**, crie o environment **`dev`** e configure:

- **Deployment branches and tags → Selected branches → `main`.** Obrigatório: impede que um
  `apply`/`destroy` disparado de outra branch assuma a role da AWS.
- **Required reviewers.** Opcional: exige aprovação antes de cada `apply`/`destroy`.

### 3. Pipeline (`.github/workflows/terraform.yml`)

| Evento | O que roda |
|---|---|
| Push na `main` que altere `infra/`, `backend/` ou o workflow | `py_compile` do handler, `fmt -check` (infra + boot-strap), `init`, `validate` e `plan` |
| **Actions → Terraform CI/CD → Run workflow → `plan`** | Igual ao push |
| … → `apply` | `plan -out` e `apply` do mesmo plano, no Environment `dev`, só a partir da `main`. O resumo do job mostra o `count_endpoint` |
| … → `plan-destroy` | Mostra o que seria destruído |
| … → `destroy` | Destrói a infra, no Environment `dev`, só a partir da `main` |

A autenticação na AWS usa **OIDC**: nenhuma chave de acesso fica guardada no GitHub.

### 4. Testar

```bash
URL="<count_endpoint do resumo do apply>"
curl -s -X POST "$URL"   # {"count": 1}
curl -s "$URL"           # {"count": 1}
```

> Enquanto o módulo `dynamodb` estiver em branco, a API responde `500`. Esse é o
> comportamento esperado. Veja [infra/modules/dynamodb/README.md](infra/modules/dynamodb/README.md).

A página de demonstração será hospedada no S3 e está a cargo do M7. O passo a passo está em
[docs/guia-frontend-s3.md](docs/guia-frontend-s3.md).

Testes do backend, CI e scanner de IaC (M3): [backend/README.md](backend/README.md).

Para rodar o Terraform localmente, veja **[infra/README.md](infra/README.md)**.

## Documentação

- [Arquitetura](docs/arquitetura.md) · [Handoffs](docs/handoffs.md)
- [Backlog](docs/backlog.md) · [Sprints](docs/sprints.md) · [Definition of Done](docs/definition-of-done.md)
- [Levantamento de requisitos](docs/Levantamento_Requisitos_Contador_de_Acessos_AWS.md)

## Demo end-to-end — Sprint 3

O roteiro manual de `curl POST → curl GET` (3 vezes), o executador automatizado com
validação e evidências locais e o checklist de aceite estão em
**[docs/demo-end-to-end.md](docs/demo-end-to-end.md)**.

> A versão deste repositório com `infra/modules/dynamodb/` em branco **não permite
> uma demonstração AWS completa**. Antes de rodar a demo na nuvem, o responsável
> precisa concluir a integração DynamoDB/IAM e publicar o endpoint `/count`.


### Teste local sem AWS (Sprint 3)

Consulte [`docs/teste-local.md`](docs/teste-local.md) para iniciar uma API local com o handler real e DynamoDB simulado, testar POST/GET e gerar evidências de 3 ciclos.

## CloudWatch — proposta Sprint 3 (linhas 31–33)

O log group da Lambda já está definido pelo módulo `lambda`. Os recursos adicionais de
monitoramento (access logs do API Gateway, Dashboard e alarme HTTP 5XX com SNS) estão
preparados no módulo `observability`, **sem execução de Terraform na AWS**.

Consulte [docs/monitoramento-sprint3.md](docs/monitoramento-sprint3.md) para decisões
de métrica, validação, evidências e dependências com a equipe. O critério literal do Jira
(`Lambda Errors > 5`) não corresponde ao comportamento atual do handler, que captura
exceções e devolve HTTP 500; a proposta usa a métrica `5XXError` do API Gateway.

**Antes do deploy:** a cópia fornecida de `.github/workflows/terraform.yml` está
totalmente comentada, e o módulo DynamoDB ainda não foi implementado.
