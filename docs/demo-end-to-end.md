# Sprint 3 — Demonstração funcional end-to-end

**Origem:** `docs/jira-import.csv`, linha 30 · **Épico:** Demo e Diferenciais · **Prioridade:** Alta · **Story Points:** 3.

**Critério de aceite:** demonstrar o fluxo `curl POST /count` → incremento → `curl GET /count` → mesmo total, **3 vezes ou mais**; arquivar evidências. O script usa o backend já presente e não interfere nas atividades de outros integrantes.

## 1. Pré-requisito fundamental

O endpoint precisa estar publicado na **AWS e integrado à tabela DynamoDB**, com permissões IAM apropriadas. **Na versão do ZIP fornecida em 29/10/2026, o módulo `infra/modules/dynamodb/` está vazio e os locals `dynamodb_table_name`/`dynamodb_table_arn` estão vazios em `infra/main.tf`.** Nesse estado, a Lambda retorna HTTP 500. A tarefa de demo não deve ser marcada como concluída enquanto a equipe não implementar e publicar essa dependência (responsabilidade M4).

Confirme com a equipe que a tabela DynamoDB e a API já foram implantadas e que o contador pode ser incrementado. **Cada POST representa um novo evento e modifica dados persistidos.** Combine uma janela de teste sem outros visitantes para que a validação `+1` seja determinística. Não zere nem apague a tabela para fazer a demo.

## 2. Encontrar o endpoint

Pelo GitHub Actions: **Actions → Terraform CI/CD → execução de `apply` → resumo do job → `count_endpoint`**.

Se tiver Terraform configurado com state remoto, na pasta `infra/`:

```powershell
terraform output -raw count_endpoint
```

Exemplo de formato (substitua pela URL real, **não** use a URL abaixo):

`https://EXEMPLO.execute-api.us-east-1.amazonaws.com/dev/count`

Não rode `terraform apply` ou `terraform destroy` sem combinar com os integrantes: o state AWS é compartilhado.

## 3. Windows — testes manuais com curl.exe

Abra **PowerShell**, na raiz do projeto:

```powershell
$URL = "https://SUA-API.execute-api.us-east-1.amazonaws.com/dev/count"

curl.exe -sS -X POST "$URL" -H "Content-Type: application/json" -d "{}"
curl.exe -sS -X GET "$URL"

curl.exe -sS -X POST "$URL" -H "Content-Type: application/json" -d "{}"
curl.exe -sS -X GET "$URL"

curl.exe -sS -X POST "$URL" -H "Content-Type: application/json" -d "{}"
curl.exe -sS -X GET "$URL"
```

Se começar com `count=42`, as respostas esperadas para os três pares são `43/43`, `44/44`, `45/45`. O valor inicial **não precisa ser zero**.

> No PowerShell, use `curl.exe` explicitamente (não o alias `curl` em algumas versões).

## 4. Windows — demo automatizada, validação e evidências

Na **raiz** do repositório, com Python 3 e curl.exe disponíveis:

```powershell
py -3 scripts\demo_end_to_end.py --url "https://SUA-API.execute-api.us-east-1.amazonaws.com/dev/count" --cycles 3
```

Se `py` não estiver configurado, use `python` em seu lugar.

O executador chama `curl` de verdade, faz GET inicial, 3 vezes (POST seguido de GET) e um GET final. Verifica que:

1. Os HTTP status são 200 e o corpo é um JSON com `count` inteiro.
2. Cada POST aumenta **exatamente 1** em relação ao GET anterior.
3. Cada GET retorna o mesmo total do POST precedente (sem modificar os dados).
4. O GET final mantém o total; o processo sai com código `0` apenas quando todos os testes passam.

Evidências locais geradas em `evidencias/demo/demo-AAAAMMDD-HHMMSS-*.txt` e `.json`. A pasta é ignorada pelo Git para não publicar dados sem revisão. Revise e selecione os arquivos que desejar compartilhar com a equipe. Se ocorrer erro, a evidência informa a falha e o script retorna código `1`.

**Saída de exemplo (ilustrativa; não é uma execução na AWS):**

```text
GET inicial: HTTP 200 | count=42 (sem incremento)
Ciclo 1: curl POST -> HTTP 200 | count=43
Ciclo 1: curl GET  -> HTTP 200 | count=43
Ciclo 2: curl POST -> HTTP 200 | count=44
Ciclo 2: curl GET  -> HTTP 200 | count=44
Ciclo 3: curl POST -> HTTP 200 | count=45
Ciclo 3: curl GET  -> HTTP 200 | count=45
GET final: HTTP 200 | count=45 (permaneceu igual)
APROVADO: 3 ciclos completos; incremento líquido = 3.
```

## 5. Validação local antes da infraestrutura AWS

Execute da **raiz do projeto**, após instalar dependências de desenvolvimento:

```powershell
py -3 -m pip install -r backend\requirements-dev.txt
py -3 -m pytest backend\tests -q
```

O teste `backend/tests/test_demo_runner.py` sobe uma API HTTP **local** que chama o handler original com DynamoDB simulado em memória e roda o script por `curl`. Isso verifica o comportamento do script sem custo AWS, mas **não comprova deploy, rede, IAM ou persistência AWS**.

## 6. Checklist para conclusão na Sprint 3

- [ ] A equipe concluiu DynamoDB/IAM e publicou o endpoint AWS `/count`.
- [ ] Testes Python locais aprovados.
- [ ] O script foi executado contra o endpoint **AWS**, não apenas contra localhost.
- [ ] Os três pares POST/GET foram aprovados sem acessos concorrentes.
- [ ] Evidências reais (`.txt`, `.json`, captura de tela) foram revisadas e anexadas ao card.
- [ ] Outro integrante conferiu a execução e a tarefa foi atualizada no board.

**Observação:** se houver outros usuários acionando o contador ao mesmo tempo, o total pode aumentar mais de 1 entre chamadas. Isso não indica necessariamente um erro do serviço, mas torna o teste estrito inconclusivo; repita em janela controlada. Em ambientes públicos, POSTs repetidos podem registrar múltiplos acessos legitimamente — são três eventos distintos, não retries seguros.
