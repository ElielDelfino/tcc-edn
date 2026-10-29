# Guia do frontend em S3 (M7)

Você vai criar a página do contador, hospedá-la no S3 e fazê-la conversar com o backend. Este
guia diz o que fazer, em que ordem e por que cada peça existe. Tasks do [backlog](backlog.md):
**6.7** (a página) e **6.9** (hospedagem no S3).

> **Versão interativa:** as lições com quiz estão em [`treinamento/`](../treinamento/index.html)
> (trilha M7). Este arquivo é a consulta.

## Como as peças se encaixam

```
Navegador ──GET──▶ S3 (site estático, HTTP) ──▶ index.html + config.js
    │
    └──POST/GET──▶ API Gateway /count ──▶ Lambda ──▶ DynamoDB
        (CORS: o API só aceita a origem do site)
```

O S3 só entrega arquivos. Quem conta os acessos é o JavaScript da página, que chama a API.

## Quem faz o quê

| Peça | Responsável | Estado |
|---|---|---|
| **IAM** da pipeline para o bucket do site | M2 (Eliel) | **Pronto.** Statement `S3FrontendBucket` em `boot-strap/policy_project.tf` |
| Página (`frontend/index.html`) | **Você** | A fazer |
| Módulo Terraform `infra/modules/frontend` | **Você** | A fazer |
| Ligar o módulo na raiz e no CORS | **Você**, revisão do M2 | A fazer |
| Passo de deploy na CI | **Você**, revisão do M2 | A fazer |

Você **não precisa escrever nenhuma permissão IAM**. Se a pipeline devolver `AccessDenied` no
bucket, avise o M2 em vez de mexer no bootstrap.

## Decisão de hospedagem: S3 website (HTTP)

Escolhemos o **site estático do S3**. É o mais barato e o que exige menos permissões. O custo:

- O endereço do site é `http://<bucket>.s3-website-<região>.amazonaws.com` (em algumas regiões,
  `s3-website.<região>`). **Não há HTTPS** nesse endpoint.
- O bucket precisa ter **leitura pública** (só `GetObject`).
- Uma página em HTTP chamando uma API em HTTPS funciona normalmente.

HTTPS com CloudFront ficou como melhoria futura (task 6.6). Fonte:
[Website endpoints (AWS)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html).

---

## Passo 1: a página

Crie `frontend/index.html`. Requisitos (task 6.7):

1. Ao abrir, envia `POST` na API (registra um acesso) e mostra o total.
2. Um botão (ou recarregar) faz `GET` e mostra o total atualizado.
3. Mostra um erro **legível** quando a chamada falha (veja a tabela abaixo).
4. **Nenhuma URL de conta ou segredo dentro do código.**

### De onde vem a URL da API

Não escreva a URL no HTML. Ela só existe depois do `apply`. A página carrega um arquivo
`config.js` que a CI gera a cada deploy (Passo 4):

```html
<script src="config.js"></script>   <!-- define window.CONTADOR_API_URL -->
<script src="app.js"></script>
```

```js
// app.js
const API = window.CONTADOR_API_URL; // ex.: https://xxxx.execute-api.us-east-1.amazonaws.com/dev/count

async function chamar(metodo) {
  const resposta = await fetch(API, {
    method: metodo,
    // O POST com Content-Type JSON força o "preflight" do CORS, o que testa a configuração inteira.
    headers: metodo === "POST" ? { "Content-Type": "application/json" } : {},
  });
  if (!resposta.ok) throw new Error(`HTTP ${resposta.status}`);
  return (await resposta.json()).count;
}
```

Crie também um `frontend/config.example.js` (`window.CONTADOR_API_URL = "COLE_A_URL_AQUI";`) e
adicione `frontend/config.js` ao `.gitignore`.

### Mensagens de erro sugeridas

| Situação | Sinal no navegador | Mensagem útil |
|---|---|---|
| Tabela ainda não existe | `500` | "O servidor não conseguiu acessar o banco." |
| Limite de requisições | `429` | "Muitas requisições. Tente de novo." |
| Rota errada | `403` | "Endereço da API incorreto." |
| CORS bloqueado ou sem rede | `fetch` lança `TypeError` | "Não foi possível falar com a API." |

### Reaproveitar a versão antiga

Havia uma página de demonstração completa (com painel e teste de concorrência) em `frontend/`.
Ela foi removida da `main` para você refazê-la, mas continua no histórico:

```bash
git show 3c38aad:frontend/index.html > /tmp/pagina-antiga.html
```

Use como **referência**, não como cópia: o objetivo é você entender cada parte. O teste de
concorrência fica **fora do escopo por enquanto**.

---

## Passo 2: o módulo `infra/modules/frontend`

Crie três arquivos. Este código foi validado com `terraform fmt` e `terraform validate`.

**`variables.tf`**

```hcl
variable "name_prefix" {
  description = "Prefixo dos recursos. A raiz passa local.name_prefix (ex: contador-acessos-dev)"
  type        = string
}
```

**`main.tf`**

```hcl
data "aws_caller_identity" "current" {}

locals {
  # O nome do bucket é único no mundo todo, então leva o ID da conta no final.
  # O trecho "-frontend-" é obrigatório: a policy da pipeline só libera buckets
  # que casam com contador-acessos-*-frontend-*.
  bucket_name = "${var.name_prefix}-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name

  # Em dev, o destroy precisa conseguir apagar o bucket mesmo com arquivos dentro.
  force_destroy = true
}

# Liberamos só a política pública (necessária para o site). ACLs públicas continuam bloqueadas.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# Transforma o bucket em site: define a página inicial e a de erro.
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Leitura pública somente dos objetos (GetObject). Nenhuma permissão de escrita ou listagem.
data "aws_iam_policy_document" "public_read" {
  statement {
    sid       = "PublicReadSite"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.public_read.json

  # A policy pública só é aceita depois que o bloqueio de política pública é desligado.
  depends_on = [aws_s3_bucket_public_access_block.site]
}
```

**`outputs.tf`**

```hcl
output "bucket_name" {
  description = "Nome do bucket do site (usado pelo deploy: aws s3 sync)"
  value       = aws_s3_bucket.site.id
}

output "website_origin" {
  description = "Origem do site (http://<endpoint>), sem barra no final. Vai para allowed_origin do CORS"
  value       = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}
```

### Por que cada recurso existe

| Recurso | Função |
|---|---|
| `aws_s3_bucket` | A pasta na nuvem onde ficam os arquivos |
| `aws_s3_bucket_public_access_block` | Chave-mestra de segurança do S3. Desligamos **só** o bloqueio de política pública |
| `aws_s3_bucket_website_configuration` | Faz o S3 responder como site (índice, erro e endpoint `s3-website`) |
| `aws_s3_bucket_policy` | A regra "qualquer pessoa pode **ler** os arquivos" |
| `depends_on` | Sem ele, o Terraform tenta anexar a policy antes de liberar o bloqueio e a AWS recusa |

### Ligar na raiz (`infra/main.tf` e `infra/output.tf`)

```hcl
module "frontend" {
  source      = "./modules/frontend"
  name_prefix = local.name_prefix
}
```

```hcl
output "frontend_bucket_name" {
  value = module.frontend.bucket_name
}

output "website_url" {
  description = "Endereço da página de demonstração"
  value       = module.frontend.website_origin
}
```

---

## Passo 3: deixar o backend disponível para o site (CORS)

**Origem** é `protocolo + domínio + porta`, por exemplo `http://meu-bucket.s3-website-us-east-1.amazonaws.com`.
O navegador só deixa a página ler a resposta da API se a API disser que aquela origem é permitida.
Isso é o **CORS** ([MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS)).

No nosso backend são duas partes, ambas controladas pela variável `allowed_origin`:

1. O **preflight** `OPTIONS`, respondido pelo próprio API Gateway (`modules/api-gateway`).
2. O header `Access-Control-Allow-Origin` na resposta da Lambda (`handler.py`).

Hoje `allowed_origin` vale `*` (qualquer origem). Troque, na raiz, para a origem do site:

```hcl
module "lambda" {
  # ...
  allowed_origin = module.frontend.website_origin
}

module "api_gateway" {
  # ...
  allowed_origin = module.frontend.website_origin
}
```

> **Cuidado com o ciclo de dependência.** O `allowed_origin` depende do módulo `frontend`. Se o
> módulo `frontend` dependesse da URL da API (por exemplo, para gravar o `config.js` pelo
> Terraform), os dois ficariam esperando um pelo outro e o Terraform recusaria o plano. Por isso
> o `config.js` **não** é criado pelo Terraform: a CI o gera depois do `apply` (Passo 4).

Peça revisão do M2 nesta mudança, porque ela altera os módulos `lambda` e `api_gateway`.

---

## Passo 4: publicar os arquivos (CI)

Depois do `apply`, a pipeline gera o `config.js` e sincroniza a pasta com o bucket. Acrescente
ao job `apply` do `.github/workflows/terraform.yml`, após o passo do `terraform apply`:

```yaml
      - name: Publicar o site no S3
        run: |
          API=$(terraform output -raw count_endpoint)
          BUCKET=$(terraform output -raw frontend_bucket_name)
          printf 'window.CONTADOR_API_URL = "%s";\n' "$API" > ../frontend/config.js
          aws s3 sync ../frontend "s3://$BUCKET" --delete --exclude "*.md" --exclude "config.example.js"
          echo "Site: $(terraform output -raw website_url)" >> "$GITHUB_STEP_SUMMARY"
```

O `working-directory` padrão do workflow é `infra`, por isso o `../frontend`. A role da
pipeline já pode escrever nesse bucket (IAM do M2).

---

## Passo 5: validar sem AWS

O bootstrap ainda não foi aplicado na AWS, então **não rode `plan` nem `apply`** (custo). Valide
o que dá para validar:

```bash
cd infra
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Para testar a página sozinha, sem backend, serve qualquer servidor local:

```bash
cp frontend/config.example.js frontend/config.js   # e coloque uma URL de teste
python3 -m http.server 8000 --directory frontend
```

### O que o scanner de IaC vai acusar

Se o checkov rodar sobre o seu módulo ([guia do M3](../backend/README.md#7-scanner-de-iac-checkov)),
espera-se cerca de **9 falhas**, a maioria sobre boas práticas que não se aplicam a um site de
demonstração (versionamento, replicação entre regiões, logs de acesso, ciclo de vida). Duas
refletem **escolhas deliberadas** do site público e devem ser aceitas com justificativa:

| ID | Regra | Por que aceitamos |
|---|---|---|
| `CKV_AWS_54` | Bloquear política pública | O site precisa de leitura pública |
| `CKV_AWS_56` | `restrict_public_buckets` ligado | Idem |

Registre o motivo com `# checkov:skip=CKV_AWS_54: site estático público, só GetObject` dentro do
resource, como mostrado no guia do M3.

## Passo 6: quando a AWS estiver ligada (teste e apresentação)

Será feito junto com o M2, depois do bootstrap:

1. `apply` pela pipeline. O resumo do job mostra o `website_url`.
2. Abrir o `website_url` no navegador e conferir que o total aumenta a cada abertura.
3. No console do navegador (aba Rede), confirmar o `OPTIONS` (preflight) e o `POST` com `200`.
4. Se aparecer erro de CORS, comparar o `allowed_origin` com a origem exata da barra de endereço
   (sem barra no final).

> Se o console da conta tiver o **Bloqueio de Acesso Público da conta inteira** ligado, o S3
> recusará a policy pública mesmo com o módulo correto. Isso se corrige no nível da conta, por
> um administrador, e não pelo Terraform do projeto. Avise o M2.

## Checklist do PR

- [ ] `frontend/index.html`, `app.js` e `config.example.js`; `frontend/config.js` no `.gitignore`
- [ ] Nenhuma URL de conta nem segredo no código
- [ ] Módulo `infra/modules/frontend` com `variables.tf`, `main.tf` e `outputs.tf`, nomes de output exatos
- [ ] Módulo ligado em `infra/main.tf`; outputs `frontend_bucket_name` e `website_url` em `infra/output.tf`
- [ ] `allowed_origin` dos módulos `lambda` e `api_gateway` apontando para `module.frontend.website_origin`
- [ ] Passo de deploy no job `apply`
- [ ] `terraform fmt -check -recursive` e `terraform validate` sem erros
- [ ] README do módulo no formato dos de `lambda` e `api-gateway`
- [ ] Na descrição do PR: "plan e teste na AWS pendentes por falta do bootstrap" (não marque como validado)

## Referências

- [Hospedar um site estático no S3 (AWS)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [Endpoints de site do S3 (AWS)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html)
- [`aws_s3_bucket_website_configuration` (Terraform)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_website_configuration)
- [CORS (MDN)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS)
