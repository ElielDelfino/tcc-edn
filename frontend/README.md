# frontend — página de demonstração

Página "Em Breve" de demonstração, que consome a API do contador. É um único `index.html`, sem
dependências nem build.

> **Escopo:** esta página é **só para demonstração local**. Ela não é implantada pela pipeline
> nem faz parte da infra Terraform. Hospedar a página na AWS (ex.: S3 + CloudFront) é uma
> melhoria futura (task 6.6).

## O que a página faz

| Parte | Comportamento |
|---|---|
| **Página "Em Breve"** (topo) | Ao abrir, envia `POST /count`, que registra um acesso, e mostra o total. É o comportamento esperado da página real do cliente |
| **Endpoint da API** | Campo para colar o `count_endpoint`. Ele fica salvo só no navegador e **nenhuma URL vai para o código** |
| **Registrar acesso automaticamente** | Desmarque para recarregar a página sem inflar o contador (passa a fazer só `GET`) |
| **Ações** | Botões `POST` (incrementa) e `GET` (só consulta) |
| **Teste de concorrência** | Dispara N `POST` simultâneos e confere se o total subiu exatamente o número de requisições aceitas (RNF-04) |
| **Log** | Método, status HTTP, latência e corpo de cada resposta |

Cada erro é explicado na tela conforme a arquitetura: `500` (Lambda/DynamoDB), `429`
(throttling), `403` (rota errada) e falha de rede/CORS.

### Por que o `POST` envia `Content-Type: application/json`

Um `POST` sem corpo seria uma requisição "simples", que o navegador manda **sem preflight**.
Com o header JSON, o navegador envia antes um `OPTIONS /count`, então a demo exercita todo o
CORS configurado: o preflight `MOCK` no API Gateway e o `Access-Control-Allow-Origin` devolvido
pela Lambda.

## Como rodar

A página precisa ser servida por HTTP. Abrir o arquivo direto (`file://`) faz o navegador
enviar a origem `null`, o que mascara o teste de CORS.

```bash
python3 -m http.server 8000 --directory frontend
```

> Se aparecer `OSError: [Errno 98] Address already in use`, a porta já é usada por outro
> serviço. Troque por outra (ex.: `8099`) e use a mesma porta na URL abaixo. Cuidado: se outro
> serviço responder na porta, o navegador abre **esse** serviço, e não a página.

Abra <http://localhost:8000> e cole o `count_endpoint`, que aparece:

- no resumo do job **Plan + Apply** da pipeline; ou
- com `terraform output -raw count_endpoint`, dentro de `infra/`.

Também dá para passar a URL direto: `http://localhost:8000/?api=<count_endpoint>`.

## CORS

Com o padrão `allowed_origin = "*"`, qualquer origem funciona. Se a variável for restringida,
ela precisa conter a origem exata da página, por exemplo:

```hcl
allowed_origin = "http://localhost:8000"
```

## Resultados esperados

| Situação | O que aparece |
|---|---|
| Infra completa (com a tabela do M4) | O total sobe a cada abertura/`POST`, e o teste de concorrência mostra "✓ Nenhum incremento perdido" |
| Módulo DynamoDB ainda em branco | `500`, com a explicação de que a tabela ainda não existe. A integração API Gateway → Lambda está funcionando |
| URL errada | `403` ou falha de rede/CORS |
