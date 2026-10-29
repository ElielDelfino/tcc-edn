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
| `conftest.py` | Carregado pelo pytest antes dos testes. Define `TABLE_NAME`, `ALLOWED_ORIGIN`, região e credenciais **falsas** antes de importar o handler (ele lê `TABLE_NAME` no import e quebraria sem ela). Se algum teste esquecer o dublê, nada chega à conta real. |
| `test_handler.py` | Os testes. A fixture `dynamo` coloca o dublê no lugar do cliente real durante cada teste e desfaz a troca no final. |

## O que cada teste verifica

| Teste | Situação simulada | O que garante |
|---|---|---|
| `test_post_incrementa_e_devolve_o_novo_total` | POST, banco responde "7" | Retorna 200 e `{"count": 7}`. O handler usa `ADD` (soma **atômica**, que não perde acessos simultâneos), a chave `hits` e o apelido `#c`, porque `count` é palavra reservada no DynamoDB |
| `test_get_devolve_o_total_com_leitura_consistente` | GET, banco tem 42 | Retorna 42 e lê com `ConsistentRead=True`, ou seja, sempre o valor mais atualizado |
| `test_get_sem_item_devolve_zero` | GET com contador ainda inexistente | Retorna 0 em vez de quebrar |
| `test_metodo_nao_permitido_devolve_405_sem_tocar_no_banco` (3 casos: DELETE, PUT, evento vazio) | Requisição inválida | Retorna 405 **e nem acessa o banco** |
| `test_erro_do_dynamodb_devolve_500_sem_vazar_detalhes` | O banco lança um erro com a mensagem "segredo" | Retorna 500 com mensagem genérica, sem vazar detalhes internos ao usuário (segurança) |
| `test_resposta_traz_header_cors_da_origem_permitida` | Qualquer resposta | O header `Access-Control-Allow-Origin` vem certo. Sem ele, o navegador bloqueia o site de chamar a API |

Total: **8 testes**, porque o teste de método não permitido roda 3 vezes com
`@pytest.mark.parametrize`.

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

Resultado esperado: `8 passed` e `Required test coverage of 80% reached`. A pasta `.venv/` já
está no `.gitignore`.

## Na CI

O job `backend-check` do [workflow](../../.github/workflows/terraform.yml) roda o mesmo comando
em Python 3.13 (runtime da Lambda). Se um teste falhar ou a cobertura ficar abaixo de 80%, o job
falha e o `plan` e o `apply` **não rodam** (`needs: backend-check`).

### Quando os testes rodam

| Gatilho | Os testes rodam? |
|---|---|
| **Push na `main`** (inclui o merge de um PR na `main`) que altere `backend/**`, `infra/**` ou o próprio workflow | Sim, automaticamente |
| **Execução manual** com `action` = `plan` ou `apply` | Sim, antes do plan/apply |
| Execução manual com `plan-destroy` ou `destroy` | Não |
| Push em outras branches (`dev`, `feat/...`) ou abertura de Pull Request | **Não** (o workflow não tem gatilho de `pull_request`) |

**Como rodar manualmente:** no GitHub, aba **Actions** → **Terraform CI/CD** → **Run workflow** →
escolha a branch e `action` = `plan`.

> O job `plan` precisa das credenciais AWS (OIDC do bootstrap). Enquanto o bootstrap não for
> aplicado, ele falha, mas o `backend-check` roda antes e mostra o resultado dos testes mesmo
> assim. Para rodar os testes também em Pull Requests, seria preciso adicionar `pull_request` ao
> `on:` do workflow (combinar com o M2 antes).

## O que eles não testam

Os testes não provam que a infraestrutura na AWS está bem configurada: permissões IAM, a tabela
existir, o API Gateway estar ligado à Lambda. Isso fica para o teste manual com `curl` (previsto
na Definition of Done) e para testes de integração. Teste de concorrência e testes `.tftest.hcl`
estão fora do escopo por enquanto.

## Resumo para a banca

> Os testes unitários validam a lógica da Lambda isolada da AWS, usando um dublê do DynamoDB, e
> provamos por mutação que eles detectam erros reais.
