# Módulo: api-gateway

Provisiona a API REST pública (Amazon API Gateway) que a página "Em Breve" chama para
registrar e consultar acessos.

## Recursos criados

| Recurso | Descrição |
|---|---|
| `aws_api_gateway_rest_api` | REST API do tipo `REGIONAL` |
| `aws_api_gateway_resource` | Recurso `/count` |
| `aws_api_gateway_method` + `aws_api_gateway_integration` (GET, POST) | Integração `AWS_PROXY` com a Lambda |
| `aws_api_gateway_method` + integração `MOCK` (OPTIONS) | Preflight CORS respondido pelo próprio API Gateway |
| `aws_api_gateway_deployment` | Snapshot publicado. É recriado quando métodos ou integrações mudam |
| `aws_api_gateway_stage` | Stage com o nome do ambiente (ex.: `dev`). Access logs ativados quando `access_log_group_arn` é informado |
| `aws_api_gateway_method_settings` | Throttling aplicado a todos os métodos do stage |
| `aws_lambda_permission` | Permite que **apenas** `/count` desta API invoque a função |

## Endpoints

| Método | Rota | Ação | Resposta |
|---|---|---|---|
| `POST` | `/<stage>/count` | Incrementa o contador | `{"count": 43}` |
| `GET` | `/<stage>/count` | Consulta o total | `{"count": 43}` |
| `OPTIONS` | `/<stage>/count` | Preflight CORS (não invoca a Lambda) | `200` com headers CORS |

Um método não configurado (ex.: `DELETE`) recebe `403` do próprio API Gateway.

## Decisões

- **REST API, e não HTTP API.** É o que está em `docs/arquitetura.md` e na estimativa de
  custos, e permite throttling por stage. A HTTP API seria mais barata (cerca de US$ 1,00 por
  milhão de requisições, contra US$ 3,50), mas não tem o mesmo controle de throttling.
- **`REGIONAL`.** Evita o CloudFront implícito do tipo EDGE, desnecessário para um único
  endpoint.
- **Throttling no stage** (padrão de 50 req/s, burst de 100). O endpoint é público e sem
  autenticação, então esse teto limita o custo em caso de abuso. As requisições excedentes
  recebem `429`.
- **CORS em duas partes.** O preflight `OPTIONS` é um `MOCK`, sem custo de Lambda. Os headers
  das respostas `GET`/`POST` são devolvidos pelo handler, porque em `AWS_PROXY` o API Gateway
  não adiciona headers.
- **`triggers` no deployment.** Sem eles, alterações em métodos ou integrações não seriam
  publicadas no stage.
- **`source_arn` restrito a `/*/*/count`.** Outras APIs ou rotas não conseguem invocar a função.
- **Access logs opcionais e sem dados pessoais.** O log group e a role da conta vêm do módulo
  `observability` (M6). Este módulo só ativa os logs no stage quando recebe o ARN. O formato JSON
  é fixo e **não inclui IP nem user agent** (RNF-09).

## Variáveis

| Nome | Tipo | Padrão | Descrição |
|---|---|---|---|
| `name` | string | — | Nome da REST API |
| `stage_name` | string | — | Nome do stage |
| `lambda_function_name` | string | — | Função invocada |
| `lambda_invoke_arn` | string | — | ARN de invocação da função |
| `allowed_origin` | string | `"*"` | Origem permitida no preflight CORS |
| `throttle_rate_limit` | number | `50` | Requisições/s em regime contínuo |
| `throttle_burst_limit` | number | `100` | Pico momentâneo |
| `access_log_group_arn` | string | `""` | Log group dos access logs. Vazio = logs desligados |

## Outputs

| Nome | Descrição |
|---|---|
| `rest_api_id` | ID da REST API |
| `rest_api_name` | Nome da REST API (dimensão `ApiName` das métricas) |
| `invoke_url` | URL base do stage |
| `count_endpoint` | URL completa de `/count` |
