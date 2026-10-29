# backend — guia de testes, CI e scanner de IaC (M3)

Este guia leva você de "nunca escrevi um teste" até a Lambda testada na CI e a infraestrutura
passando por um scanner de segurança. É a base da **task 3.5** do [backlog](../docs/backlog.md).

> **Versão interativa:** as mesmas lições, com quiz e cartões de revisão, estão no artefato Claude
> do M3 (<https://claude.ai/artifact/SKWZqYv3ThgguKBN6qMhHS>; peça acesso ao M2). Use o quiz para
> fixar, e este arquivo como consulta.

## O que criar e onde

Os arquivos abaixo **já existem vazios** no repositório. Você preenche os marcados com "escreve" e
edita os marcados com "edita".

```
TCC-EdN-AWS/
├── backend/
│   ├── contador/handler.py            # código da Lambda (já existe, não mexer)
│   ├── tests/
│   │   ├── conftest.py                # escreve (seção 4.1): variáveis de ambiente antes do import
│   │   └── test_handler.py            # escreve (seções 4.2 a 4.4): os testes
│   └── requirements-dev.txt           # escreve (seção 6.1): pytest, pytest-cov, boto3
├── .checkov.yaml                      # escreve (seção 7.2): soft-fail + hard-fail-on do PITR
├── .github/workflows/terraform.yml    # edita: jobs backend-check e iac-scan (seções 6.2 a 6.5)
└── docs/decisao-criptografia-dynamodb.md   # NÃO é seu: o M4 escreve (task 4.4); o skip do checkov o cita
```

---

## 1. O que é um teste unitário

Um **teste unitário** executa uma peça pequena do código (uma função) isolada do resto do mundo
e confere o resultado. Ele precisa ser:

| Propriedade | Significado | No nosso caso |
|---|---|---|
| Rápido | Milissegundos | 8 testes rodam em menos de 1 s |
| Isolado | Sem rede, banco, nuvem | Nunca chama a AWS de verdade |
| Determinístico | Mesmo resultado sempre | O DynamoDB "responde" o que o teste mandar |

**Por que não testar contra o DynamoDB real?** Custaria dinheiro, exigiria credenciais na CI,
dependeria da internet e do bootstrap (que ainda não foi aplicado) e seria lento. Além disso,
não conseguiríamos provocar um erro do DynamoDB quando quiséssemos. O teste unitário troca a AWS
por um **dublê** (um objeto falso que devolve o que combinamos).

Teste unitário **não** prova que a AWS está bem configurada. Isso é papel do teste manual com
`curl` (já previsto na Definition of Done) e do teste de integração, que fica para depois.

## 2. O que é o boto3

O **boto3** é o SDK oficial da AWS para Python. No handler:

```python
dynamodb = boto3.client("dynamodb")
```

`client("dynamodb")` cria um objeto cujos métodos (`update_item`, `get_item`...) viram chamadas
HTTPS assinadas para a API do DynamoDB. Três pontos que aparecem no código:

- **Valores tipados.** O cliente de baixo nível exige o tipo de cada valor: `{"S": "hits"}` é
  texto (String) e `{"N": "1"}` é número, **escrito como texto**. Por isso o handler faz
  `int(result["Attributes"]["count"]["N"])`.
- **Credenciais.** Na Lambda elas vêm sozinhas da role de execução. No seu computador e na CI,
  não existem. Criar o cliente exige só uma **região**, e a primeira chamada de verdade falharia.
- **Respostas são dicionários.** `get_item` devolve `{"Item": {...}}` quando existe e `{}` quando
  não existe. O handler trata os dois casos.

Referência: [`update_item` na documentação do boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/dynamodb/client/update_item.html).

## 3. Lendo o handler, trecho a trecho

Arquivo: [`contador/handler.py`](contador/handler.py). A tabela liga cada conceito de Python ao
motivo de ele estar ali.

| Trecho | Conceito de Python | Por que está assim |
|---|---|---|
| `TABLE_NAME = os.environ["TABLE_NAME"]` | `os.environ` é um dicionário das variáveis de ambiente. Com `[...]`, a chave ausente levanta `KeyError` | **Falhar cedo**: sem tabela configurada, a função nem sobe, em vez de dar erro estranho depois |
| `os.environ.get("COUNTER_ID", "hits")` | `.get(chave, padrão)` devolve o padrão se a chave não existir | Valores opcionais com padrão seguro |
| `dynamodb = boto3.client("dynamodb")` fora de qualquer função | **Código no nível do módulo roda uma vez, quando o arquivo é importado** | Na Lambda, o ambiente é reaproveitado entre invocações. Criar o cliente uma vez evita refazê-lo a cada chamada (menos latência depois do cold start) |
| `def _response(status_code: int, body: dict) -> dict:` | **Type hints** (`int`, `dict`, `->`) documentam os tipos. O Python não os impõe | Legibilidade e ajuda do editor. O `_` no início é convenção de "uso interno" |
| `json.dumps(body, ensure_ascii=False)` | Converte dicionário em texto JSON. `ensure_ascii=False` mantém acentos | O API Gateway (integração proxy) exige `body` como **texto**, não dicionário |
| `UpdateExpression="ADD #c :one"` | Expressão do DynamoDB, não do Python | `ADD` é **atômico**: duas requisições simultâneas não se sobrescrevem e o item é criado na primeira chamada |
| `ExpressionAttributeNames={"#c": "count"}` | Dicionário que dá um apelido ao atributo | `count` é palavra reservada no DynamoDB. O apelido `#c` contorna isso |
| `ConsistentRead=True` | Parâmetro nomeado (`chave=valor`) | A leitura reflete todos os incrementos já confirmados |
| `item = result.get("Item")` e `... if item else 0` | **Expressão condicional** e valor "falsy" (`None`, `{}` são falsos) | Contador ainda inexistente vale 0 |
| `event.get("httpMethod")` | `.get` não quebra se a chave faltar | Um evento estranho vira `None` e cai no 405 |
| `try: ... except Exception:` | Captura qualquer erro | Nenhum erro vaza para o cliente |
| `logger.exception(...)` | Registra a mensagem **e o stack trace** | O erro completo vai para o CloudWatch, e o cliente recebe só "Erro interno" |
| `return` dentro de `if` | **Retorno antecipado** | Evita `if/else` aninhados |

**Fluxo da requisição:** o API Gateway chama `lambda_handler(event, context)`. Em `event` vem o
método (`httpMethod`). `POST` chama `_increment()`, `GET` chama `_get_total()`, qualquer outro
devolve `405`, e qualquer exceção devolve `500` com log.

## 4. Como escrever testes válidos

Um teste é **válido** quando ele falha se o código estiver errado. Um teste que sempre passa
é pior que nenhum, porque dá falsa segurança. Quatro decisões garantem isso aqui.

### 4.1 As variáveis de ambiente existem antes do `import`

O handler lê `TABLE_NAME` e cria o cliente **no momento do import**. Se o teste importar o
handler antes de definir a variável, o import quebra com `KeyError`. O `conftest.py` é carregado
pelo pytest antes dos testes, então é o lugar certo:

```python
# backend/tests/conftest.py
import os
import sys
from pathlib import Path

os.environ["TABLE_NAME"] = "tabela-de-teste"
os.environ["ALLOWED_ORIGIN"] = "https://site-de-teste.example"
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"   # o boto3 exige região para criar o cliente
os.environ["AWS_ACCESS_KEY_ID"] = "teste"        # credenciais falsas: se algum teste esquecer o
os.environ["AWS_SECRET_ACCESS_KEY"] = "teste"    # dublê, nada chega à conta real

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "contador"))
```

### 4.2 O cliente real é trocado por um dublê, só durante o teste

```python
# backend/tests/test_handler.py
import json
from unittest.mock import MagicMock

import pytest
from botocore.exceptions import ClientError

import handler


@pytest.fixture
def dynamo(monkeypatch):
    """Troca o cliente real do módulo por um dublê, só durante o teste."""
    fake = MagicMock()
    monkeypatch.setattr(handler, "dynamodb", fake)
    return fake
```

- `MagicMock()` é o dublê: aceita qualquer chamada e guarda como foi chamado.
- `monkeypatch.setattr` troca `handler.dynamodb` e **desfaz a troca sozinho** ao fim do teste.
- Uma **fixture** (`@pytest.fixture`) é uma função que prepara algo para o teste. O teste a
  recebe só por declarar o nome como parâmetro.

### 4.3 O teste confere o que foi enviado, não só o que voltou

O dublê devolve o que mandarmos, então conferir só o retorno testaria o próprio dublê. O teste
verifica **como o handler chamou o DynamoDB**:

```python
def test_post_incrementa_e_devolve_o_novo_total(dynamo):
    # Arrange: o "DynamoDB" vai responder que o total agora é 7
    dynamo.update_item.return_value = {"Attributes": {"count": {"N": "7"}}}

    # Act
    response = handler.lambda_handler({"httpMethod": "POST"}, None)

    # Assert: resposta correta E chamada correta
    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == {"count": 7}
    dynamo.update_item.assert_called_once_with(
        TableName="tabela-de-teste",
        Key={"id": {"S": "hits"}},
        UpdateExpression="ADD #c :one",
        ExpressionAttributeNames={"#c": "count"},
        ExpressionAttributeValues={":one": {"N": "1"}},
        ReturnValues="UPDATED_NEW",
    )
```

A estrutura **Arrange-Act-Assert** (preparar, executar, conferir) deixa cada teste legível.

### 4.4 Os casos de borda também são testados

| Caso | O que prova |
|---|---|
| `GET` com item existente | Lê com `ConsistentRead=True` e devolve o número |
| `GET` sem item (`{}`) | Devolve `{"count": 0}` |
| Método `DELETE`, `PUT` e evento vazio (`@pytest.mark.parametrize`) | `405` e o banco nem é tocado (`assert_not_called`) |
| `update_item` levanta `ClientError` (`side_effect`) | `500`, e a mensagem interna **não** aparece no corpo |
| Qualquer resposta | Traz `Access-Control-Allow-Origin` igual a `ALLOWED_ORIGIN` |

> **Sua tarefa:** escreva os cinco casos acima seguindo o modelo do teste do `POST`. Dica para o
> erro do banco: `dynamo.update_item.side_effect = ClientError({"Error": {"Code": "X", "Message": "segredo"}}, "UpdateItem")`.

### 4.5 Prova de que os testes protegem o código (mutação)

Os testes deste guia foram executados contra o handler real e depois **quebrados de propósito**:

| Alteração feita no handler | Resultado |
|---|---|
| `ADD #c :one` trocado por `SET #c :one` | 1 teste falhou |
| `ConsistentRead=True` trocado por `False` | 1 teste falhou |
| `"statusCode": status_code` trocado por `200` fixo | 4 testes falharam |

Faça o mesmo com a sua suíte: altere uma linha do handler, rode os testes e confirme que algum
falha. Se nada falhar, o teste não protege aquela linha. **Cobertura de 80% mede linhas
executadas, não qualidade**: a mutação mede se o teste percebe o erro.

## 5. Rodando no seu computador

```bash
# na raiz do repositório
python3 -m venv .venv && source .venv/bin/activate
pip install -r backend/requirements-dev.txt
pytest backend/tests --cov=backend/contador --cov-report=term-missing --cov-fail-under=80
```

Esperado: `8 passed` (ou o número de testes que você escrever) e `Required test coverage of 80% reached`.
Adicione `.venv/` ao `.gitignore`.

## 6. Colocando na CI

### 6.1 `backend/requirements-dev.txt`

O `boto3` **não vem instalado** no runner do GitHub Actions (só existe dentro da Lambda), e o
handler o importa. Versões testadas neste guia: pytest 9.2.0, pytest-cov 7.1.0, boto3 1.43.121.

```text
pytest==9.2.0
pytest-cov==7.1.0
boto3==1.43.121
```

### 6.2 YAML em 5 minutos

O arquivo `.github/workflows/terraform.yml` é **YAML**: um formato de texto para descrever dados em
árvore, sem chaves nem ponto e vírgula. O GitHub lê esse texto e executa a pipeline. Há só
cinco ideias:

| Ideia | Como se escreve | Exemplo do nosso arquivo |
|---|---|---|
| **Chave e valor** | `chave: valor` (espaço depois dos dois pontos) | `runs-on: ubuntu-latest` |
| **Aninhamento** | O **recuo** (espaços) mostra quem está dentro de quem | `steps:` está dentro de `backend-check:` |
| **Lista** | Cada item começa com `- ` | `branches:` seguido de `- main` |
| **Texto** | Com ou sem aspas; use aspas se tiver `:` ou `*` | `paths: - "infra/**"` |
| **Comentário** | Começa com `#` e vai até o fim da linha | `# mesmo runtime da Lambda` |

```yaml
# Isto é um comentário: o GitHub ignora.
nome-do-job:                 # chave cujo valor é um bloco (tudo que está recuado abaixo)
  runs-on: ubuntu-latest     # chave: valor simples
  steps:                     # chave cujo valor é uma LISTA
    - uses: actions/checkout@v4      # item 1 (um bloco com a chave 'uses')
    - name: Rodar testes             # item 2: bloco com duas chaves, 'name' e 'run'
      run: pytest                    #   'run' está alinhada com 'name': mesmo item
    - name: Vários comandos
      run: |                         # '|' = o texto abaixo é um bloco de várias linhas
        pip install checkov
        checkov -d infra
```

**Os três erros que mais acontecem:**

1. **Recuo errado.** São sempre **espaços** (2 por nível), nunca TAB. Um item deslocado vira
   outro item ou quebra o arquivo. Se `run:` não estiver alinhada com `name:`, ela deixa de
   pertencer ao passo.
2. **Dois pontos dentro do texto.** `name: Testes: unitários` quebra. Escreva
   `name: "Testes: unitários"`.
3. **Esquecer o `- `** no começo de um passo novo: sem ele, as chaves se misturam no passo anterior.

> **Dica:** valide antes de fazer o commit. No seu computador:
> `pip install actionlint-py && actionlint .github/workflows/terraform.yml`. Sem saída = sem erros.
> O `actionlint` entende a estrutura do GitHub Actions, não só o YAML. Testei a versão nova desta
> seção com ele: passou sem avisos.

### 6.3 Como o workflow atual está organizado

O arquivo tem sempre esta hierarquia: **workflow → jobs → passos (steps)**.

```yaml
name: Terraform CI/CD          # nome do workflow, mostrado na aba Actions

on:                            # GATILHOS: quando ele roda
  push:                        #   a cada push...
    branches: [main]           #   ...na main (no arquivo real é uma lista escrita em linhas)
  workflow_dispatch:           #   ou quando alguém clica "Run workflow" no GitHub

permissions:                   # o que o token do GitHub pode fazer
  contents: read               #   ler o código
  id-token: write              #   pedir credencial temporária da AWS (OIDC)

env:                           # variáveis de ambiente visíveis em todos os jobs
  TERRAFORM_VERSION: "1.16.0"

defaults:
  run:
    working-directory: infra   # todo 'run' começa em infra/, salvo se disser outro

jobs:                          # JOBS: cada um roda numa máquina própria; por padrão, ao mesmo tempo
  backend-check: { ... }       #   hoje: só compila o handler
  plan:          { ... }       #   terraform init + validate + plan
  apply:         { ... }       #   terraform apply (manual, só na main)
  plan-destroy:  { ... }
  destroy:       { ... }
```

Dentro de cada job: `runs-on` (a máquina), `if` (condição para rodar), `needs` (quem precisa
terminar antes) e `steps` (a lista de passos). Cada passo faz **uma** de duas coisas:

- `uses:` chama uma **action** pronta (ex.: `actions/checkout@v4` baixa o código);
- `run:` executa **comandos de shell** (ex.: `pytest ...`).

Em `${{ ... }}` o GitHub troca a expressão por um valor na hora de rodar (ex.:
`${{ secrets.AWS_ROLE_ARN }}` vira o segredo guardado no repositório).

### 6.4 O que muda: hoje e depois, lado a lado

Você faz **quatro mudanças** no mesmo arquivo. Em cada quadro, a esquerda é o que existe hoje e a
direita é o que deve ficar, com um comentário em cada linha importante. Comentários em YAML são
inofensivos: pode copiá-los ou apagá-los.

**1. Quando roda (`on.push.paths`)**

<table>
<tr><th width="50%">Hoje</th><th width="50%">Depois (com comentários)</th></tr>
<tr>
<td valign="top">

<pre>on:
  push:
    branches:
      - main
    paths:
      - "infra/**"
      - "backend/**"
      - ".github/workflows/terraform.yml"</pre>

</td>
<td valign="top">

<pre># QUANDO o workflow roda
on:
  # ao enviar commits...
  push:
    branches:
      # ...para a main
      - main
    # e só se mudou um destes caminhos
    paths:
      - "infra/**"
      - "backend/**"
      # NOVO: alterar a config do scanner também dispara a CI
      - ".checkov.yaml"
      - ".github/workflows/terraform.yml"</pre>

</td>
</tr>
</table>

**2. O job `backend-check`**

<table>
<tr><th width="50%">Hoje</th><th width="50%">Depois (com comentários)</th></tr>
<tr>
<td valign="top">

<pre>  backend-check:
    name: Backend (py_compile)
    runs-on: ubuntu-latest
    if: github.event_name == 'push' || github.event.inputs.action == 'plan' || github.event.inputs.action == 'apply'

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.13" # mesmo runtime da Lambda

      - name: Compilar handler
        working-directory: .
        run: python -m py_compile backend/contador/handler.py</pre>

</td>
<td valign="top">

<pre>  # id do job: o nome que outros jobs usam em 'needs'
  backend-check:
    # nome mostrado na aba Actions do GitHub
    name: Backend (testes)
    # máquina virtual Linux que o GitHub empresta
    runs-on: ubuntu-latest
    # só roda em push, ou quando escolhem plan/apply à mão
    if: github.event_name == 'push' || github.event.inputs.action == 'plan' || github.event.inputs.action == 'apply'

    # lista de passos, executados em ordem (cada '- ' é um passo)
    steps:
      # baixa o código do repositório para a máquina
      - uses: actions/checkout@v4

      # instala o Python (uma 'action' pronta, com parâmetros em 'with')
      - uses: actions/setup-python@v5
        with:
          # a mesma versão da Lambda
          python-version: "3.13" # mesmo runtime da Lambda
          # NOVO: guarda os pacotes baixados entre execuções (mais rápido)
          cache: pip
          # NOVO: o cache é refeito quando este arquivo muda
          cache-dependency-path: backend/requirements-dev.txt

      # NOVO: instala pytest, pytest-cov e boto3
      - name: Instalar dependências de teste
        # o arquivo usa 'infra' como padrão; aqui voltamos à raiz
        working-directory: .
        # comando de shell; o runner não tem o boto3
        run: pip install -r backend/requirements-dev.txt

      # confere se o handler tem erro de sintaxe
      - name: Compilar handler
        working-directory: .
        run: python -m py_compile backend/contador/handler.py

      # NOVO: roda os testes e falha se a cobertura ficar abaixo de 80%
      - name: Testes unitários (cobertura mínima de 80%)
        working-directory: .
        run: pytest backend/tests --cov=backend/contador --cov-report=term-missing --cov-fail-under=80</pre>

</td>
</tr>
</table>

**3. O job `iac-scan` (não existe hoje)**

<table>
<tr><th width="50%">Hoje</th><th width="50%">Depois (com comentários)</th></tr>
<tr>
<td valign="top">

```text
(não existe)
```

</td>
<td valign="top">

<pre>  # NOVO job, independente do backend-check: os dois rodam ao mesmo tempo
  iac-scan:
    # nome mostrado na aba Actions
    name: Scanner IaC (checkov)
    runs-on: ubuntu-latest
    # mesma regra do backend-check
    if: github.event_name == 'push' || github.event.inputs.action == 'plan' || github.event.inputs.action == 'apply'

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.13"

      - name: Checkov
        working-directory: .
        # '|' = bloco de várias linhas, cada linha é um comando
        run: |
          # instala o checkov em versão fixa (reprodutível)
          pip install checkov==3.1.47
          # lê o .checkov.yaml: avisa, e só o PITR derruba o job
          checkov --config-file .checkov.yaml</pre>

</td>
</tr>
</table>

**4. Quem espera quem (`needs`) em `plan` e `apply`**

<table>
<tr><th width="50%">Hoje</th><th width="50%">Depois (com comentários)</th></tr>
<tr>
<td valign="top">

<pre>  plan:
    name: Init + Validate + Plan
    runs-on: ubuntu-latest
    if: github.event_name == 'push' || github.event.inputs.action == 'plan'

  apply:
    name: Plan + Apply
    runs-on: ubuntu-latest
    needs: backend-check
    if: github.event.inputs.action == 'apply' &amp;&amp; github.ref == 'refs/heads/main'</pre>

</td>
<td valign="top">

<pre>  plan:
    name: Init + Validate + Plan
    runs-on: ubuntu-latest
    # NOVO: este job só começa depois que os dois terminarem verdes.
    # Se um teste ou o scanner (PITR) falhar, o job é pulado.
    needs: [backend-check, iac-scan]
    if: github.event_name == 'push' || github.event.inputs.action == 'plan'

  apply:
    name: Plan + Apply
    runs-on: ubuntu-latest
    # NOVO: este job só começa depois que os dois terminarem verdes.
    # Se um teste ou o scanner (PITR) falhar, o job é pulado.
    needs: [backend-check, iac-scan]
    if: github.event.inputs.action == 'apply' &amp;&amp; github.ref == 'refs/heads/main'</pre>

</td>
</tr>
</table>

Para quem prefere aplicar tudo de uma vez, este é o **patch exato** (gerado com `diff -u` e
conferido com `git apply --check` sobre o arquivo atual). Linhas com `+` entram, com `-` saem:

```diff
--- a/.github/workflows/terraform.yml
+++ b/.github/workflows/terraform.yml
@@ -7,6 +7,7 @@
     paths:
       - "infra/**"
       - "backend/**"
+      - ".checkov.yaml"
       - ".github/workflows/terraform.yml"
   workflow_dispatch:
     inputs:
@@ -49,7 +50,7 @@
   # Backend — verificação do código da Lambda (sem AWS)
   # -------------------------------------------------------
   backend-check:
-    name: Backend (py_compile)
+    name: Backend (testes)
     runs-on: ubuntu-latest
     if: github.event_name == 'push' || github.event.inputs.action == 'plan' || github.event.inputs.action == 'apply'
 
@@ -59,11 +60,42 @@
       - uses: actions/setup-python@v5
         with:
           python-version: "3.13" # mesmo runtime da Lambda
+          cache: pip
+          cache-dependency-path: backend/requirements-dev.txt
+
+      - name: Instalar dependências de teste
+        working-directory: .
+        run: pip install -r backend/requirements-dev.txt
 
       - name: Compilar handler
         working-directory: .
         run: python -m py_compile backend/contador/handler.py
 
+      - name: Testes unitários (cobertura mínima de 80%)
+        working-directory: .
+        run: pytest backend/tests --cov=backend/contador --cov-report=term-missing --cov-fail-under=80
+
+  # -------------------------------------------------------
+  # Scanner de IaC — lê o Terraform sem executá-lo (sem AWS)
+  # -------------------------------------------------------
+  iac-scan:
+    name: Scanner IaC (checkov)
+    runs-on: ubuntu-latest
+    if: github.event_name == 'push' || github.event.inputs.action == 'plan' || github.event.inputs.action == 'apply'
+
+    steps:
+      - uses: actions/checkout@v4
+
+      - uses: actions/setup-python@v5
+        with:
+          python-version: "3.13"
+
+      - name: Checkov
+        working-directory: .
+        run: |
+          pip install checkov==3.1.47
+          checkov --config-file .checkov.yaml
+
   # -------------------------------------------------------
   # Plan — roda em todo push na main e quando action=plan
   # Valida o código e mostra o que será alterado
@@ -71,6 +103,7 @@
   plan:
     name: Init + Validate + Plan
     runs-on: ubuntu-latest
+    needs: [backend-check, iac-scan]
     if: github.event_name == 'push' || github.event.inputs.action == 'plan'
 
     steps:
@@ -108,7 +141,7 @@
   apply:
     name: Plan + Apply
     runs-on: ubuntu-latest
-    needs: backend-check
+    needs: [backend-check, iac-scan]
     if: github.event.inputs.action == 'apply' && github.ref == 'refs/heads/main'
     environment: dev
 
```

Para usar: salve como `pipeline.patch` na raiz e rode `git apply pipeline.patch`. Depois confira
com `git diff` e rode o `actionlint`.

### 6.5 Conferindo o resultado

- Os passos `Testes unitários` e `Checkov` só passam quando existirem `backend/tests/` com testes
  de verdade e o `.checkov.yaml` (seção 7.2). **Enquanto `test_handler.py` estiver vazio, o
  `pytest` termina com erro "no tests ran"** e o job fica vermelho. Faça o commit do workflow
  junto com os testes.
- `needs` em `plan` e `apply` faz um teste quebrado **impedir** o plan e o apply. É esse o
  objetivo: o time só altera a infraestrutura com o backend verde.
- Mudou o `on.paths`? Lembre que o workflow só dispara em push na `main` com mudança nesses
  caminhos. O `on:` já tem `pull_request` para a `main`, então o scanner também avisa no PR.

## 7. Scanner de IaC (checkov)

Um **scanner de IaC** lê o Terraform sem executá-lo e aponta configurações inseguras ou fora de
boas práticas. Usamos o [checkov](https://www.checkov.io/). Ele não precisa de credenciais AWS.

```bash
pip install checkov==3.1.47
checkov -d infra --framework terraform --compact --quiet
```

### 7.1 O que esperar na primeira execução

Executado sobre o `infra/` atual: **32 verificações passam e 21 falham**. Exemplos reais:

| ID | O que cobra | Faz sentido para nós? |
|---|---|---|
| `CKV_AWS_59` | API sem acesso aberto | Não: a API é pública por requisito do case |
| `CKV_AWS_117` | Lambda dentro de uma VPC | Não: uma VPC traria custo (NAT) sem ganho aqui |
| `CKV_AWS_50` / `CKV_AWS_73` | X-Ray ligado | Talvez, como melhoria futura |
| `CKV_AWS_116` | Dead Letter Queue na Lambda | Não: a invocação é síncrona |
| `CKV2_AWS_29` | WAF no API Gateway | Melhoria futura (custo) |

Moral: scanner mede *boas práticas genéricas*, não o *nosso contexto*. Cada falha vira uma de
três decisões: **corrigir**, **aceitar com justificativa** (skip) ou **adiar**.

### 7.2 Estratégia para a CI: avisar sem quebrar, bloquear só o que importa

Se o scanner quebrasse a CI hoje, ninguém conseguiria fazer merge. Crie `.checkov.yaml` na raiz:

```yaml
directory:
  - infra
framework:
  - terraform
compact: true
quiet: true
soft-fail: true          # mostra as falhas, mas não derruba o job
hard-fail-on:            # estas, sim, derrubam o job
  - CKV_AWS_28           # PITR do DynamoDB precisa estar ligado
```

Testado: com PITR ligado o checkov sai com código `0`. Removendo o bloco `point_in_time_recovery`
da tabela, sai com `1`. Com o tempo, você move checks de "aviso" para `hard-fail-on`.

O job `iac-scan` (sem credenciais AWS, por isso independente do `plan`) está comentado
linha a linha na seção 6.4, quadro 3. Ele lê este `.checkov.yaml` com `--config-file`.

> O workflow roda em push na `main` e em Pull Request para a `main`, com mudanças em `infra/`,
> `backend/` ou no próprio workflow. Sem credenciais AWS o `plan` falha, mas o scanner e os testes
> mostram o resultado antes.

### 7.3 Aceitar uma falha com justificativa (skip)

O comentário `checkov:skip` fica **dentro do resource**, perto da decisão, com o motivo escrito:

```hcl
resource "aws_dynamodb_table" "this" {
  # checkov:skip=CKV_AWS_119: dado não sensível (só um contador); usamos a chave de
  # propriedade da AWS, sem custo. Ver docs/decisao-criptografia-dynamodb.md
  name = "${var.name_prefix}-counter"
  # ...
}
```

Testado: o relatório passa a mostrar `Skipped checks: 1` em vez de `Failed checks: 1`. Documentação:
[Suppressing and Skipping Policies](https://www.checkov.io/2.Basics/Suppressing%20and%20Skipping%20Policies.html).

## 8. O que é CMK e por que o scanner acusa o DynamoDB

**CMK** (*Customer Managed Key*, ou chave gerenciada pelo cliente) é uma chave do AWS KMS que
**você** cria, possui e gerencia: política da chave, ativar/desativar, rotação, alias e
agendamento de exclusão.

O DynamoDB criptografa todos os dados em repouso com **AES-256**, qualquer que seja o tipo de
chave. O que muda é **quem é o dono da chave**:

| Tipo de chave | Quem gerencia | Custo (fonte: AWS) | Visível na sua conta |
|---|---|---|---|
| **Chave de propriedade da AWS** (padrão) | A AWS | Sem taxa mensal nem de uso | Não |
| **Chave gerenciada pela AWS** (`aws/dynamodb`) | A AWS, na sua conta | Sem taxa mensal; cobrança por requisições ao KMS | Sim, e auditável no CloudTrail |
| **CMK** (chave gerenciada pelo cliente) | Você | US$ 1/mês por chave (proporcional por hora) + US$ 0,03 por 10 mil requisições; 20 mil requisições grátis por mês | Sim |

Fontes: [criptografia em repouso do DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/encryption.howitworks.html)
e [preços do AWS KMS](https://aws.amazon.com/kms/pricing/).

**Por que o `CKV_AWS_119` falha?** A regra se chama *"Ensure DynamoDB Tables are encrypted using
a KMS Customer Managed CMK"* e só passa com uma CMK. Testamos as duas opções do projeto:

| Configuração da tabela | Resultado do checkov |
|---|---|
| Sem bloco `server_side_encryption` (chave da AWS) | `CKV_AWS_119` **falha** |
| `server_side_encryption { enabled = true }` (chave `aws/dynamodb`) | `CKV_AWS_119` **falha** |

Ou seja: o scanner não distingue as duas escolhas. Só uma CMK passa. A regra existe porque
certas normas de conformidade exigem controle sobre a chave (desativá-la, auditá-la, girá-la). O
scanner não sabe que a nossa tabela guarda só um número.

### A decisão do projeto

A tabela usa a **chave de propriedade da AWS** (o "AES256" que o projeto escolheu). Os motivos:

1. **O dado não é sensível.** A tabela guarda o total de acessos.
2. **Simplicidade.** Nenhuma chave para criar, rotacionar ou proteger. A role da pipeline
   (`boot-strap/policy_project.tf`) não tem nenhuma permissão `kms:*`.
3. **Risco de uma CMK.** Se alguém a desativa ou agenda a exclusão, a tabela fica
   **inacessível** (a AWS dá 7 dias para corrigir antes de arquivá-la). Seria risco extra para
   um benefício que o case não pede.
4. **Custo é argumento fraco.** O DynamoDB não chama o KMS a cada operação (renova a chave a cada
   5 minutos por chamador), então a diferença seria pequena. A decisão se apoia nos itens 1 a 3.

Quem registra a decisão é o M4, em `docs/decisao-criptografia-dynamodb.md` (task 4.4). O `skip`
da seção 7.3 aponta para esse documento. Se a banca perguntar, a resposta é: *conhecemos a
regra, avaliamos o risco e registramos por que a aceitamos*.

## 9. Checklist da task 3.5

- [ ] `backend/requirements-dev.txt` com as versões fixas
- [ ] `backend/tests/conftest.py` e `test_handler.py` com os 6 casos da seção 4
- [ ] Cobertura ≥ 80% localmente
- [ ] Mutação feita em pelo menos 2 linhas do handler, com testes falhando
- [ ] Job `backend-check` com `pytest` e `needs: backend-check` no `plan`
- [ ] `.checkov.yaml` e job `iac-scan` (avisando, com `hard-fail-on` do PITR)
- [ ] `.venv/` no `.gitignore`
- [ ] Teste de concorrência: **fora do escopo por enquanto** (será definido depois)
- [ ] Testes `.tftest.hcl`: **fora do escopo**

## Referências

- [pytest: primeiros passos](https://docs.pytest.org/en/stable/getting-started.html)
- [`unittest.mock`](https://docs.python.org/3/library/unittest.mock.html)
- [Handler Python da AWS Lambda](https://docs.aws.amazon.com/lambda/latest/dg/python-handler.html)
- [pytest-cov: configuração](https://pytest-cov.readthedocs.io/en/latest/config.html)
- [GitHub Actions para Python](https://docs.github.com/en/actions/tutorials/build-and-test-code/python)
- [Catálogo de regras do checkov](https://www.checkov.io/5.Policy%20Index/terraform.html)
