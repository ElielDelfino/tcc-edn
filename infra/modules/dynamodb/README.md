# Módulo: dynamodb — guia de implementação (M4)

> **Status:** módulo **em branco**. `main.tf`, `variables.tf` e `outputs.tf` existem, mas estão
> vazios. Este guia descreve o que precisa ser feito para o contador funcionar ponta a ponta.
>
> **Responsável:** M4 (Dados e Segurança). Tasks 4.1, 4.4 e 4.6 do [backlog](../../../docs/backlog.md).

## Situação atual

O restante da infra já está pronto e sobe sem a tabela:

```
Página ──▶ API Gateway (/count) ──▶ Lambda ──✗──▶ DynamoDB (ainda não existe)
```

Enquanto este módulo estiver vazio, a raiz (`infra/main.tf`) passa nome e ARN da tabela como
`""` (placeholders). Com isso:

- a Lambda é criada **sem** permissão no DynamoDB;
- `GET` e `POST /count` respondem **`500`**, e o erro aparece no log group da Lambda.

Isso é esperado. Depois que você terminar os passos abaixo, as respostas passam a ser `200`.

---

## 1. O que criar em `main.tf`

Uma tabela `aws_dynamodb_table` com:

| Configuração | Valor | Por quê |
|---|---|---|
| Nome | `"${var.name_prefix}-counter"` → `contador-acessos-dev-counter` | **Obrigatório** começar com `contador-acessos-`, ver o aviso abaixo |
| `hash_key` | `id`, tipo `S` (string) | Chave de partição usada pela Lambda (RF-04) |
| `range_key` | **nenhuma** | O contador é um único item |
| `billing_mode` | `PAY_PER_REQUEST` (on-demand) | Volume incerto, sem capacidade ociosa (RNF-01, RNF-02) |
| Criptografia em repouso | Bloco `server_side_encryption` | Task 4.4. Veja a escolha de chave abaixo |
| PITR | Bloco `point_in_time_recovery { enabled = true }` | Task 4.6. Permite restaurar o contador por até 35 dias |
| `deletion_protection_enabled` | `false` em `dev` | A pipeline precisa conseguir rodar `destroy` depois da demo |

> ⚠️ **Prefixo obrigatório.** A role do GitHub Actions (`boot-strap/policy_project.tf`) só
> tem permissão em `table/contador-acessos-*`. Uma tabela com outro nome faz a pipeline falhar
> com `AccessDenied`.

**Escolha de chave de criptografia (task 4.4):** registre a decisão em `docs/`.

| Opção | Configuração | Custo |
|---|---|---|
| Chave de propriedade da AWS (padrão) | Sem bloco `server_side_encryption` | Sem custo. A tabela já é criptografada por padrão |
| Chave gerenciada pela AWS (`aws/dynamodb`) | `server_side_encryption { enabled = true }` | Cobrança por requisição ao KMS. A chave aparece no console e no CloudTrail |

**Não** é preciso criar `attribute` para `count`. O DynamoDB só exige a definição dos
atributos que fazem parte de chaves ou índices.

### ❌ Não crie o item `hits` pelo Terraform

**Não** use `aws_dynamodb_table_item` para criar o item `{ id = "hits", count = 0 }`. A cada
apply, o Terraform veria que o `count` mudou e o **zeraria**, apagando os acessos. O item não
precisa existir antes:

- o primeiro `POST` cria o item (`UpdateItem` com `ADD` funciona em item inexistente);
- um `GET` antes disso retorna `{"count": 0}`.

## 2. Contrato com a Lambda (não alterar)

O handler (`backend/contador/handler.py`) espera exatamente isto:

| Item | Valor |
|---|---|
| Chave de partição | `id` (S) |
| Valor da chave do contador | `"hits"` |
| Atributo do total | `count` (N) |

Mudar qualquer um desses nomes exige alterar o handler junto, o que é responsabilidade do M3.

## 3. `variables.tf`: inputs do módulo

| Variável | Tipo | Obrigatória | Uso |
|---|---|---|---|
| `name_prefix` | string | Sim | Prefixo do nome da tabela. A raiz passa `local.name_prefix` (`contador-acessos-dev`) |

Não é preciso variável de tags: o provider da raiz já aplica `Project`, `Environment` e
`ManagedBy` em todos os recursos (`default_tags`).

## 4. `outputs.tf`: outputs obrigatórios

**Use exatamente estes nomes.** A raiz e a Lambda dependem deles:

| Output | Valor |
|---|---|
| `table_name` | Nome da tabela |
| `table_arn` | ARN da tabela |

## 5. Ligar o módulo na raiz (`infra/main.tf` e `infra/output.tf`)

**a) Passe o input no bloco do módulo:**

```hcl
module "dynamodb" {
  source      = "./modules/dynamodb"
  name_prefix = local.name_prefix
}
```

**b) Troque os dois placeholders no bloco `locals`** (há um `TODO(M4)` marcando o lugar):

```hcl
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
```

Só isso. O módulo `lambda` cria a policy `dynamodb:UpdateItem` + `dynamodb:GetItem`
**restrita ao ARN da tabela** automaticamente quando o nome deixa de ser vazio (RNF-03). Você
não precisa escrever IAM.

**c) Exponha o nome da tabela** em `infra/output.tf`, para a demo (task 2.4):

```hcl
output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}
```

> Essa ligação foi testada com um `terraform plan` offline: o plan resultante cria a tabela e a
> policy `dynamodb-counter` da Lambda sem erros.

## 6. Validar

### Localmente

```bash
cd infra
terraform fmt -recursive
terraform init -backend-config="bucket=<TF_STATE_BUCKET>"
terraform validate
terraform plan
```

No `plan`, confira que aparecem:

- `module.dynamodb.aws_dynamodb_table.<nome>` **will be created**
- `module.lambda.aws_iam_role_policy.dynamodb[0]` **will be created**
- `module.lambda.aws_lambda_function.this` **will be updated in-place** (`TABLE_NAME` deixa de ser `""`)

### Na pipeline

1. Abra um PR para `main`. Depois do merge, o workflow **Terraform CI/CD** roda o `plan`.
2. Revise o plan no log do job.
3. Rode o workflow manualmente (**Actions → Terraform CI/CD → Run workflow → `apply`**).

### Ponta a ponta

```bash
URL=$(terraform output -raw count_endpoint)

curl -s "$URL"            # {"count": 0}   — item ainda não existe
curl -s -X POST "$URL"    # {"count": 1}
curl -s -X POST "$URL"    # {"count": 2}
curl -s "$URL"            # {"count": 2}

aws dynamodb get-item \
  --table-name "$(terraform output -raw dynamodb_table_name)" \
  --key '{"id":{"S":"hits"}}'
```

## 7. Checklist do PR

- [ ] Tabela com nome `contador-acessos-<env>-…`, PK `id` (S), on-demand
- [ ] Criptografia em repouso definida e a escolha de chave documentada (4.4)
- [ ] PITR habilitado (4.6)
- [ ] `deletion_protection_enabled = false` em dev
- [ ] **Nenhum** `aws_dynamodb_table_item`
- [ ] Outputs `table_name` e `table_arn` com esses nomes exatos
- [ ] Placeholders do `locals` trocados e `name_prefix` passado na raiz
- [ ] Output `dynamodb_table_name` adicionado em `infra/output.tf`
- [ ] `terraform fmt -check -recursive` e `terraform validate` sem erros
- [ ] `plan` revisado: tabela e policy `dynamodb[0]` criadas, nada destruído
- [ ] Teste com `curl` mostrando `POST` incrementando e `GET` lendo
- [ ] Este README atualizado: troque o guia pela documentação do módulo (recursos, variáveis
      e outputs), no mesmo formato dos módulos `lambda` e `api-gateway`

https://registry.terraform.io/providers/hashicorp/aws/latest/docs