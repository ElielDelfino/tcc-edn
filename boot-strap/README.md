# boot-strap

Configuração Terraform que cria a fundação necessária **antes** de qualquer pipeline do
GitHub Actions funcionar:

- o bucket S3 do state remoto da infra (`infra/`);
- o OIDC provider do GitHub Actions na conta AWS;
- a role IAM que a pipeline assume via OIDC, sem chaves de acesso guardadas no GitHub.

## O que é criado

### Bucket S3: state remoto do Terraform

- Versionamento habilitado, para recuperar versões anteriores do state
- Criptografia SSE-S3 (AES256)
- Bloqueio total de acesso público
- `force_destroy = false`: o bucket só é apagado se estiver vazio

O lock do state usa o lock nativo do S3 (`use_lockfile = true`, Terraform ≥ 1.10), então
não é preciso uma tabela DynamoDB de lock.

### OIDC provider: `token.actions.githubusercontent.com`

Permite que o GitHub Actions troque um token OIDC por credenciais temporárias da AWS.
**Só pode existir um por conta.** Se a conta já tiver um, de outro projeto, use
`create_oidc_provider = false` e ele será reaproveitado.

### Role IAM: `project_name` (ex.: `GithubActionsContadorAcessos`)

**Trust policy:** só podem assumir a role os workflows do repositório `github_owner/github_repo`
em uma destas situações:

| `sub` do token OIDC | Quem usa |
|---|---|
| `repo:<owner>/<repo>:ref:refs/heads/main` | Jobs de `plan` disparados na branch `main` |
| `repo:<owner>/<repo>:environment:dev` | Jobs de `apply`/`destroy`, que rodam no GitHub Environment `dev` |

Pull requests e outras branches **não** conseguem assumir a role.

**Policy inline `terraform-state-and-infra`:** em vez das policies `*FullAccess`, cada serviço
fica restrito aos recursos com o prefixo do projeto (`resource_prefix`, padrão
`contador-acessos`):

| Statement | Escopo |
|---|---|
| `TerraformStateBucket` / `TerraformStateObjects` | Apenas o bucket de state (inclui o `.tflock`) |
| `DynamoDBProjectTables` | `table/contador-acessos-*` |
| `LambdaProjectFunctions` | `function:contador-acessos-*` |
| `APIGateway` | `/restapis*` (os IDs são gerados pela AWS, então não dá para filtrar por nome) e `/account` (role de logs da conta) |
| `CloudWatchLogsProjectGroups` | `log-group:/aws/lambda/contador-acessos-*` e `/aws/apigateway/contador-acessos-*` |
| `CloudWatchLogsDescribe` | `logs:DescribeLogGroups` em `*` (a API não aceita restrição por recurso) |
| `CloudWatchProjectDashboards` | `dashboard/contador-acessos-*` |
| `CloudWatchProjectAlarms` | `alarm:contador-acessos-*` |
| `CloudWatchDescribe` | `DescribeAlarms` e `ListDashboards` em `*` (só leitura, sem restrição por recurso) |
| `SNSProjectTopics` | Tópicos `contador-acessos-*` e suas assinaturas |
| `S3FrontendBucket` | Buckets `contador-acessos-*-frontend-*` e seus objetos (site estático do M7 e deploy dos arquivos). O bucket de state não entra |
| `IAMProjectRoles` | Roles `role/contador-acessos-*` e suas policies inline |
| `AttachAPIGatewayLogsPolicy` | Anexar policy gerenciada **somente** `AmazonAPIGatewayPushToCloudWatchLogs` |
| `PassProjectRoles` | `iam:PassRole` dessas roles **somente** para `lambda.amazonaws.com` e `apigateway.amazonaws.com` |

> **Consequência:** todo recurso criado em `infra/` precisa ter o nome começando com
> `contador-acessos-`. Caso contrário, a pipeline recebe `AccessDenied`.

---

## Pré-requisitos

- Terraform ≥ 1.10
- AWS CLI configurado com credenciais de administrador (ou permissão para criar roles IAM,
  OIDC provider e bucket S3). É o único passo que usa credenciais pessoais.

## Como usar

### 1. Ajuste as variáveis

```bash
cd boot-strap
cp terraform.tfvars.example terraform.tfvars   # terraform.tfvars não é versionado
```

```hcl
aws_region     = "us-east-1"
project_name   = "GithubActionsContadorAcessos"
github_owner   = "ElielDelfino"
github_repo    = "tcc-edn"
s3_bucket_name = "contador-acessos-tfstate-<sufixo-unico>"
```

### 2. Inicialize e aplique

```bash
terraform init
terraform plan
terraform apply
```

### 3. Configure o repositório no GitHub

Em **Settings → Secrets and variables → Actions**:

| Tipo | Nome | Valor |
|---|---|---|
| Secret | `AWS_ROLE_ARN` | output `project_role_arn` |
| Variable | `TF_STATE_BUCKET` | output `s3_bucket_name` |
| Variable | `AWS_REGION` | output `s3_bucket_region` |
| Secret (opcional) | `ALARM_EMAIL` | E-mail que recebe os alarmes do CloudWatch (vazio = sem assinatura) |

Em **Settings → Environments**, crie o environment `dev`. Opcionalmente, marque
*Required reviewers* para que todo apply/destroy precise de aprovação.

---

## Variáveis

| Variável | Descrição | Obrigatória |
|---|---|---|
| `aws_region` | Região AWS | Não (padrão: `us-east-1`) |
| `project_name` | Nome da role IAM criada | Sim |
| `github_owner` | Usuário ou organização do GitHub | Sim |
| `github_repo` | Nome do repositório GitHub | Sim |
| `github_environment` | Environment dos jobs de apply/destroy | Não (padrão: `dev`) |
| `s3_bucket_name` | Nome do bucket de state (único globalmente) | Sim |
| `create_oidc_provider` | Cria o OIDC provider (`false` se já existir) | Não (padrão: `true`) |
| `resource_prefix` | Prefixo dos recursos que a role pode gerenciar | Não (padrão: `contador-acessos`) |

O ID da conta não é uma variável: ele vem de `data.aws_caller_identity`.

## Outputs

| Output | Uso |
|---|---|
| `project_role_arn` | Secret `AWS_ROLE_ARN` |
| `s3_bucket_name` | Variable `TF_STATE_BUCKET` |
| `s3_bucket_region` | Variable `AWS_REGION` |
| `github_oidc_provider_arn` | Referência |

---

## Importante

- Execute **uma única vez por conta/projeto**, antes de qualquer pipeline.
- O state deste diretório fica **local** (`terraform.tfstate`): ele não pode morar no bucket
  que ele mesmo cria. O `.gitignore` da raiz impede que esse arquivo seja versionado. Guarde
  uma cópia em local seguro, porque sem ele não dá para alterar ou destruir o bootstrap pelo
  Terraform.
- O `.terraform.lock.hcl` **é versionado**, para que todo o grupo use as mesmas versões do
  provider.
