# Teste local da demonstração Sprint 3 (sem AWS)

Este procedimento usa o **handler Python real da Lambda**, mas substitui o DynamoDB por armazenamento **simulado em memória**. O servidor aceita requisições apenas de `127.0.0.1` (seu próprio computador). Ele não cria recursos na AWS nem persiste os valores quando fechado.

## Pré-requisitos

- Python 3 disponível como `py -3` no Windows (alternativamente, `python`).
- `curl.exe` disponível no Windows.
- Na raiz do projeto, instale dependências: `py -3 -m pip install -r backend\requirements-dev.txt`.

## Passo 1: iniciar a API local

**PowerShell 1**, na raiz do projeto:

```powershell
py -3 scripts\api_local.py --port 8765 --initial 41
```

Deixe essa janela aberta. O endpoint será `http://127.0.0.1:8765/count`.

## Passo 2: testar manualmente

**PowerShell 2**:

```powershell
$URL = "http://127.0.0.1:8765/count"
curl.exe -sS -X GET $URL
curl.exe -sS -X POST $URL -H "Content-Type: application/json" -d "{}"
curl.exe -sS -X GET $URL
```

Se começou em 41, as respostas serão `{"count":41}`, `{"count":42}`, `{"count":42}`. Cada novo POST incrementa mais um.

## Passo 3: testar três ciclos e salvar evidências

Ainda no **PowerShell 2**, na raiz do projeto:

```powershell
py -3 scripts\demo_end_to_end.py --url "http://127.0.0.1:8765/count" --cycles 3
```

O script faz GET inicial, três pares de POST/GET e GET final, gera evidências `.txt` e `.json` em `evidencias/demo/` e informa `APROVADO: 3 ciclos completos`. A contagem não precisa começar em 41; o script lê o valor real inicial.

## Testes automatizados adicionais

```powershell
py -3 -m pytest backend\tests -q
```

Esses testes validam o handler e o executador com mocks, incluindo um teste que reprova incrementos incorretos.

## Limitação

A aprovação local não prova acesso, IAM, API Gateway, infraestrutura Terraform, persistência DynamoDB nem deploy na AWS. Para encerrar o critério de aceite de produção, repita o script contra o endpoint AWS implantado e anexar as evidências dessa execução.
