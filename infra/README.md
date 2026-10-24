# infra

Infraestrutura AWS do Contador de Acessos, provisionada com Terraform. O state fica no bucket
S3 criado pelo [boot-strap](../boot-strap/README.md), com lock nativo do S3.

## Estrutura

```
infra/
├── backend.tf               # backend S3 (bucket passado no init, lock nativo)
├── main.tf                  # providers, default_tags, locals e chamada dos módulos
├── variables.tf             # variáveis de entrada (todas com default)
├── output.tf                # outputs do state
├── .terraform.lock.hcl      # versões dos providers (versionado, multi-plataforma)
├── env/
│   └── dev.tfvars.example   # copie para dev.tfvars (não versionado) para mudar valores
└── modules/
    ├── lambda/              # função Python 3.13 arm64, role de execução, log group
    ├── api-gateway/         # REST API regional, GET/POST /count, CORS, throttling
    └── dynamodb/            # ⚠️ em branco — guia para o M4 no README do módulo
```

## Módulos

| Módulo | Descrição | Status |
|---|---|---|
| [`lambda`](modules/lambda/README.md) | Função do contador, role com menor privilégio e log group com retenção | Pronto |
| [`api-gateway`](modules/api-gateway/README.md) | Endpoint público `/count`, CORS e throttling no stage | Pronto |
| [`dynamodb`](modules/dynamodb/README.md) | Tabela do contador | **Em branco (M4)** |

## Nomes dos recursos

Todos os recursos seguem o padrão `${project_name}-${environment}-…`
(`contador-acessos-dev-…`). **Não mude esse prefixo:** a role da pipeline só tem permissão em
recursos que começam com `contador-acessos-` (veja `boot-strap/policy_project.tf`).

| Recurso | Nome |
|---|---|
| Lambda | `contador-acessos-dev-counter` |
| Role da Lambda | `contador-acessos-dev-counter-role` |
| Log group | `/aws/lambda/contador-acessos-dev-counter` |
| REST API | `contador-acessos-dev-api` (stage `dev`) |
| Tabela DynamoDB | `contador-acessos-dev-counter` (a ser criada pelo M4) |

## Variáveis

| Variável | Padrão | Descrição |
|---|---|---|
| `aws_region` | `us-east-1` | Região dos recursos |
| `project_name` | `contador-acessos` | Primeira parte do nome dos recursos |
| `environment` | `dev` | Ambiente e nome do stage da API |
| `allowed_origin` | `*` | Origem permitida no CORS. Em produção, o domínio da página |
| `throttle_rate_limit` | `50` | Requisições/s em regime contínuo |
| `throttle_burst_limit` | `100` | Pico momentâneo de requisições |
| `log_retention_days` | `14` | Retenção dos logs da Lambda |
| `lambda_memory_mb` | `128` | Memória da Lambda |
| `lambda_timeout_s` | `5` | Timeout da Lambda |

## Outputs

| Output | Descrição |
|---|---|
| `count_endpoint` | URL de `/count`, usada pela página e pela demo |
| `api_invoke_url` | URL base do stage |
| `lambda_function_name` | Nome da função |
| `lambda_log_group_name` | Log group da função no CloudWatch |

## Rodando localmente

O caminho normal é a pipeline (veja o [README da raiz](../README.md)). Para rodar da sua
máquina, você precisa de credenciais AWS com permissão sobre os recursos do projeto.

```bash
cd infra

# 1. Inicializa com o bucket de state criado pelo boot-strap
terraform init -backend-config="bucket=<TF_STATE_BUCKET>"

# 2. Formata e valida
terraform fmt -recursive
terraform validate

# 3. Planeja e aplica (o -var-file é opcional: todas as variáveis têm default)
terraform plan  -var-file=env/dev.tfvars
terraform apply -var-file=env/dev.tfvars

# 4. Consulta os outputs
terraform output count_endpoint

# 5. Destrói (evita custo depois da demo)
terraform destroy -var-file=env/dev.tfvars
```

Para validar sem acessar a AWS (sem state remoto):

```bash
terraform init -backend=false
terraform validate
```

> **Cuidado:** a pipeline e a execução local compartilham o **mesmo state**. O lock nativo do
> S3 impede execuções simultâneas, mas combine com o grupo antes de rodar `apply`/`destroy`
> localmente.
