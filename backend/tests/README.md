# Testes unitários da Lambda

Este documento explica o que os testes de `backend/tests/` fazem, para que servem e como rodá-los.
O passo a passo completo (teoria, CI e checkov) está no [guia do backend](../README.md).

## Para que servem

A Lambda [`contador/handler.py`](../contador/handler.py) é o "cérebro" do contador. Quando alguém
acessa o site, o API Gateway chama essa função:

- **POST** soma 1 no contador do DynamoDB.
- **GET** lê o total.
- Outros métodos recebem **405**.
- Se algo der erro, a resposta é **500**.

Os testes verificam automaticamente que esse comportamento continua certo, **sem precisar subir
nada na AWS**. Se alguém alterar o handler e quebrar alguma coisa, um teste falha antes de o
código chegar ao ambiente.

## Como funcionam sem a AWS

O handler conversa com o DynamoDB pelo `boto3`. Nos testes, o DynamoDB de verdade é trocado por
um **dublê**, um objeto falso (`MagicMock`) que:

1. **Responde o que mandamos.** Por exemplo: "finja que o total agora é 7".
2. **Registra como foi chamado.** Assim conferimos se o handler pediu a coisa certa ao banco.

Por isso o teste é grátis, roda em cerca de 1 segundo, não exige credenciais e dá sempre o mesmo
resultado.

| Arquivo | Papel |
|---|---|
| `conftest.py` | Carregado pelo pytest antes dos testes. Define `TABLE_NAME`, `ALLOWED_ORIGIN`, região e credenciais **falsas** antes de importar o handler (ele lê `TABLE_NAME` no import e quebraria sem ela). Limpa `AWS_PROFILE`, `AWS_SESSION_TOKEN`, `AWS_ENDPOINT_URL` e `COUNTER_ID` da máquina e desliga a busca de credenciais no IMDS, para o resultado não depender de quem roda. Se algum teste esquecer o dublê, nada chega à conta real. |
| `test_handler.py` | Os testes. A fixture `dynamo` coloca o dublê no lugar do cliente real durante cada teste e desfaz a troca no final. O dublê é `MagicMock(spec=handler.dynamodb)`: só aceita métodos que o cliente boto3 de verdade tem. |

## O que cada teste verifica

| Teste | Situação simulada | O que garante |
|---|---|---|
| `test_post_incrementa_e_devolve_o_novo_total` | POST, banco responde "7" | Retorna 200 e `{"count": 7}`. O handler usa `ADD` (soma **atômica**, que não perde acessos simultâneos), a chave `hits` e o apelido `#c`, porque `count` é palavra reservada no DynamoDB |
| `test_get_devolve_o_total_com_leitura_consistente` | GET, banco tem 42 | Retorna 42 e lê com `ConsistentRead=True`, ou seja, sempre o valor mais atualizado |
| `test_get_sem_item_devolve_zero` | GET com contador ainda inexistente | Retorna 0 em vez de quebrar |
| `test_metodo_nao_permitido_devolve_405_sem_tocar_no_banco` (3 casos: DELETE, PUT, evento vazio) | Requisição inválida | Retorna 405 **e nem acessa o banco** |
| `test_erro_do_dynamodb_devolve_500_sem_vazar_detalhes` | POST, o banco lança um erro com a mensagem "segredo" | Retorna 500 com mensagem genérica, sem vazar detalhes internos ao usuário (segurança) |
| `test_resposta_traz_header_cors_da_origem_permitida` | Qualquer resposta | O header `Access-Control-Allow-Origin` vem certo. Sem ele, o navegador bloqueia o site de chamar a API |
| `test_erro_do_dynamodb_devolve_500_em_post_e_get` (2 casos) | O banco falha no POST e no GET | 500 nos dois métodos, sem vazar a mensagem |
| `test_resposta_malformada_do_dynamodb_devolve_500` | O item volta sem o atributo `count` | `KeyError` vira 500, não derruba a Lambda |
| `test_log_de_erro_existe_e_nao_contem_dados_do_visitante` | Erro com IP e User-Agent no evento | O erro é logado (`caplog`), mas sem IP nem User-Agent (RNF-09) |
| `test_usa_o_counter_id_configurado` | `COUNTER_ID` diferente do padrão | POST e GET usam o nome configurado, não `hits` fixo |
| `test_sem_allowed_origin_o_padrao_e_asterisco` | Variável `ALLOWED_ORIGIN` ausente | CORS cai em `*` (carrega uma cópia do módulo, sem afetar os outros testes) |
| `test_corpo_preserva_acentos_sem_escape_unicode` | Resposta 405 | `"Método não permitido"` sai legível, sem `\u00e9` |
| `test_todas_as_respostas_trazem_cors_e_content_type` (3 casos) | Respostas 200, 405 e 500 | CORS e `Content-Type` em todas, não só no GET |

Total: **18 testes**, porque alguns rodam várias vezes com `@pytest.mark.parametrize` (método não
permitido, erro em POST/GET, headers). Os 8 primeiros vieram no PR #5; os demais foram acrescentados
na revisão, para matar mutações que sobreviviam.

Cada teste segue o padrão **Arrange → Act → Assert**: preparar o cenário, executar o handler e
conferir o resultado. Os testes conferem também **como o handler chamou o DynamoDB**, não só o
que ele devolveu. Como o dublê devolve o que mandamos, conferir só o retorno testaria o próprio
dublê.

## Por que confiar neles

Um teste que sempre passa não protege nada. Por isso o handler foi quebrado de propósito
(**teste de mutação**) e conferimos que algum teste falhava:

| Alteração feita no handler | Resultado |
|---|---|
| `ADD` trocado por `SET` (o contador viraria sempre 1) | 1 teste falhou |
| `ConsistentRead=True` trocado por `False` | 1 teste falhou |
| `statusCode` fixo em 200 | 4 testes falharam |
| Origem do CORS trocada por `*` | 1 teste falhou |
| `ensure_ascii=False` trocado por `True` | 1 teste falhou |
| `COUNTER_ID` fixo em `"hits"` (no POST ou no GET) | 1 teste falhou em cada |
| Padrão de `ALLOWED_ORIGIN` trocado de `*` para outro valor | 1 teste falhou |
| `logger.exception` removido, ou trocado por um log do `event` inteiro | 1 teste falhou em cada |
| POST passando a chamar `get_item` também | 1 teste falhou |
| `try/except` mantido só no POST | 5 testes falharam |

A **cobertura de 100%** mostra que todas as linhas do handler foram executadas. A mutação mostra
que os testes **percebem** quando alguma delas está errada.

## Como rodar

Na raiz do repositório:

```bash
# Linux/macOS
python3 -m venv .venv && source .venv/bin/activate

# Windows (PowerShell)
python -m venv .venv; .venv\Scripts\Activate.ps1

pip install -r backend/requirements-dev.txt
pytest backend/tests --cov=backend/contador --cov-report=term-missing --cov-fail-under=80
```

Resultado esperado: `18 passed` e `Required test coverage of 80% reached`. A pasta `.venv/` já
está no `.gitignore`.

## Na CI

O job `backend-check` do [workflow](../../.github/workflows/terraform.yml) roda o mesmo comando
em Python 3.13 (runtime da Lambda). Se um teste falhar ou a cobertura ficar abaixo de 80%, o job
falha e o `plan` e o `apply` **não rodam** (`needs: backend-check`).

### Quando os testes rodam

| Gatilho | Os testes rodam? |
|---|---|
| **Push na `main`** (inclui o merge de um PR na `main`) que altere `backend/**`, `infra/**` ou o próprio workflow | Sim, automaticamente |
| **Pull Request para a `main`** (abrir ou atualizar) que altere esses mesmos caminhos | Sim |
| **Execução manual** com `action` = `plan` ou `apply` | Sim, antes do plan/apply |
| Execução manual com `plan-destroy` ou `destroy` | Não |
| Push em outras branches (`dev`, `feat/...`) | **Não** |

**Como rodar manualmente:** no GitHub, aba **Actions** → **Terraform CI/CD** → **Run workflow** →
escolha a branch `main` e `action` = `plan`.

> **No Pull Request**, rodam `backend-check` (estes testes) e `infra-check` (`terraform fmt` e
> `validate`, sem AWS). O `plan` **não roda em PR**: a role da AWS só aceita a `main` e o environment
> `dev`, então um PR seria recusado sempre. Isso é de propósito e não deve ser "consertado"
> afrouxando a role. O `plan` manual também só funciona escolhendo a `main`. No push da `main`, o
> `plan` ainda depende do bootstrap (credenciais AWS) ser aplicado, mas o `backend-check` roda antes
> e mostra o resultado dos testes mesmo assim.

## O que eles não testam

Os testes não provam que a infraestrutura na AWS está bem configurada: permissões IAM, a tabela
existir, o API Gateway estar ligado à Lambda. Isso fica para o teste manual com `curl` (previsto
na Definition of Done) e para testes de integração. Teste de concorrência e testes `.tftest.hcl`
estão fora do escopo por enquanto.

## Resumo para a banca

> Os testes unitários validam a lógica da Lambda isolada da AWS, usando um dublê do DynamoDB, e
> provamos por mutação que eles detectam erros reais.
