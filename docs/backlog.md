# Product Backlog

Organizado por Epics. Cada item tem prioridade, estimativa em Story Points (SP), e responsável sugerido. Use este backlog para popular o board no Notion.

**Escala de Story Points:** 1 = trivial (< 1h), 2 = pequeno (1–2h), 3 = médio (meio dia), 5 = grande (1 dia), 8 = muito grande (dividir se possível)

---

## EPIC 1: Planejamento e Requisitos
**Owner:** Membro 1 (PO)

| ID | User Story | SP | Prioridade | Responsável | Sprint |
|----|-----------|-----|-----------|-------------|--------|
| 1.1 | Documentar o entendimento do problema do cliente | 2 | Alta | M1 | 1 |
| 1.2 | Levantar requisitos funcionais (RF) | 2 | Alta | M1 | 1 |
| 1.3 | Levantar requisitos não funcionais (RNF) | 2 | Alta | M1 | 1 |
| 1.4 | Criar mapeamento requisito ↔ serviço AWS (tabela) | 3 | Alta | M1 + M5 | 1 |
| 1.5 | Definir Definition of Done para cada entrega | 1 | Média | M1 + M5 | 1 |

---

## EPIC 2: Arquitetura e Infraestrutura (CDK)
**Owner:** Membro 2 (Arquitetura)

| ID | User Story | SP | Prioridade | Responsável | Sprint |
|----|-----------|-----|-----------|-------------|--------|
| 2.1 | Criar diagrama de arquitetura (fluxo de acesso + dados + segurança) | 3 | Alta | M2 | 1 |
| 2.2 | Inicializar projeto CDK (Python ou TypeScript) | 2 | Alta | M2 | 1 |
| 2.3 | Criar stack principal com todos os recursos (API GW + Lambda + DynamoDB) | 5 | Alta | M2 + M3 + M4 | 2 |
| 2.4 | Configurar outputs do CDK (URL do API Gateway, nome da tabela) | 1 | Média | M2 | 2 |
| 2.5 | Documentar como fazer deploy (`cdk deploy`, pré-requisitos) | 2 | Média | M2 | 2 |
| 2.6 | Configurar .gitignore e organização do repositório | 1 | Alta | M2 | 1 |

---

## EPIC 3: Backend — Lambda + API Gateway
**Owner:** Membro 3 (Backend)

| ID | User Story | SP | Prioridade | Responsável | Sprint |
|----|-----------|-----|-----------|-------------|--------|
| 3.1 | Implementar função Lambda (handler: incrementar contador no DynamoDB) | 3 | Alta | M3 | 2 |
| 3.2 | Configurar API Gateway (rota POST /count ou GET /count) | 3 | Alta | M3 + M2 | 2 |
| 3.3 | Configurar CORS no API Gateway (se front-end acessar diretamente) | 2 | Média | M3 | 2 |
| 3.4 | Implementar endpoint GET para consultar total de acessos | 2 | Média | M3 | 2 |
| 3.5 | Escrever testes unitários para a Lambda | 3 | Média | M3 | 3 |
| 3.6 | Documentar os endpoints (método, URL, payload, resposta) | 2 | Média | M3 | 3 |

---

## EPIC 4: Dados e Segurança
**Owner:** Membro 4 (Dados + Segurança)

| ID | User Story | SP | Prioridade | Responsável | Sprint |
|----|-----------|-----|-----------|-------------|--------|
| 4.1 | Criar tabela DynamoDB (Partition Key: `id`, tipo `S`) | 2 | Alta | M4 | 2 |
| 4.2 | Configurar IAM Role para Lambda (permissões mínimas: `dynamodb:UpdateItem`, `dynamodb:GetItem`) | 3 | Alta | M4 | 2 |
| 4.3 | Documentar estratégia de segurança (IAM, least privilege, encryption at rest) | 3 | Alta | M4 | 2 |
| 4.4 | Configurar encryption at rest no DynamoDB | 1 | Média | M4 | 2 |
| 4.5 | Avaliar e documentar: VPC necessária? (spoiler: não, para serverless puro) | 2 | Média | M4 | 2 |
| 4.6 | Configurar backup automático do DynamoDB (Point-in-Time Recovery) | 2 | Média | M4 | 3 |

---

## EPIC 5: Escalabilidade, Custos e Resiliência
**Owner:** Membro 5 (Scrum Master)

| ID | User Story | SP | Prioridade | Responsável | Sprint |
|----|-----------|-----|-----------|-------------|--------|
| 5.1 | Documentar como cada serviço escala (Lambda: concurrency, DynamoDB: on-demand, API GW: managed) | 3 | Alta | M5 | 2 |
| 5.2 | Identificar gargalos potenciais (Lambda cold start, DynamoDB throttling) | 3 | Alta | M5 | 3 |
| 5.3 | Criar estimativa de custos com AWS Pricing Calculator (cenários: 100, 10k, 1M acessos/mês) | 5 | Alta | M5 | 3 |
| 5.4 | Documentar estratégia de resiliência (Multi-AZ automático do DynamoDB, Lambda retries) | 3 | Média | M5 | 3 |
| 5.5 | Documentar plano de otimização de custos (Reserved Capacity, Provisioned vs On-Demand) | 2 | Média | M5 | 3 |

---

## EPIC 6: Demonstração, Monitoramento e Diferenciais
**Owner:** Membro 6 (Demo)

| ID | User Story | SP | Prioridade | Responsável | Sprint |
|----|-----------|-----|-----------|-------------|--------|
| 6.1 | Preparar demonstração funcional (curl/Postman → API → Lambda → DynamoDB → resposta) | 3 | Alta | M6 + M3 | 3 |
| 6.2 | Configurar CloudWatch Logs para a Lambda | 2 | Média | M6 | 3 |
| 6.3 | Criar CloudWatch Dashboard (métricas: invocations, errors, duration, DynamoDB read/write) | 3 | Média | M6 | 3 |
| 6.4 | Configurar CloudWatch Alarm (ex: erros > 5 em 5 min) | 2 | Baixa | M6 | 3 |
| 6.5 | Documentar estratégia de recuperação (re-deploy via CDK, restore DynamoDB) | 3 | Média | M6 + M4 | 3 |
| 6.6 | Propor melhorias futuras (CI/CD, página front-end, analytics, rate limiting) | 2 | Média | M6 | 3 |

---

## EPIC 7: Apresentação e Entrega Final
**Owner:** Membro 1 (PO) — Todos participam

| ID | User Story | SP | Prioridade | Responsável | Sprint |
|----|-----------|-----|-----------|-------------|--------|
| 7.1 | Criar estrutura dos 16 slides | 3 | Alta | M1 | 3 |
| 7.2 | Slide 1–4: Capa, Problema, Requisitos, Visão Geral | 3 | Alta | M1 | 4 |
| 7.3 | Slide 5: Diagrama de Arquitetura | 3 | Alta | M2 | 4 |
| 7.4 | Slide 6: Explicação dos Serviços AWS | 3 | Alta | M3 + M4 | 4 |
| 7.5 | Slide 7: Justificativa Técnica | 2 | Alta | M2 + M4 | 4 |
| 7.6 | Slide 8: Mapeamento de Requisitos | 2 | Alta | M1 + M5 | 4 |
| 7.7 | Slides 9–10: Escalabilidade e Resiliência | 3 | Alta | M5 | 4 |
| 7.8 | Slide 11: Segurança | 2 | Alta | M4 | 4 |
| 7.9 | Slide 12: Custos | 2 | Alta | M5 | 4 |
| 7.10 | Slide 13: Recuperação | 2 | Alta | M6 + M4 | 4 |
| 7.11 | Slide 14: Demonstração (preparar evidências/screenshots) | 3 | Alta | M6 | 4 |
| 7.12 | Slides 15–16: Diferenciais e Conclusão | 2 | Alta | M6 + M1 | 4 |
| 7.13 | Ensaio geral da apresentação (todos) | 3 | Alta | Todos | 4 |
| 7.14 | Preparação para perguntas da banca (cada um estuda as perguntas da sua área) | 3 | Alta | Todos | 4 |
| 7.15 | Revisão final e checklist de entrega | 2 | Alta | M1 + M5 | 4 |

---

## Resumo do Backlog

| Epic | Qtd de Itens | Total SP | Sprint Principal |
|------|-------------|----------|-----------------|
| 1. Planejamento e Requisitos | 5 | 10 | Sprint 1 |
| 2. Arquitetura e CDK | 6 | 14 | Sprint 1–2 |
| 3. Backend (Lambda + API GW) | 6 | 15 | Sprint 2–3 |
| 4. Dados e Segurança | 6 | 13 | Sprint 2–3 |
| 5. Escalabilidade e Custos | 5 | 16 | Sprint 2–3 |
| 6. Demo e Diferenciais | 6 | 15 | Sprint 3 |
| 7. Apresentação | 15 | 37 | Sprint 3–4 |
| **Total** | **49** | **120** | |
#mexi no codigo