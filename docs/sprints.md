# Planejamento de Sprints

> **Nota:** Ajuste as datas reais conforme o prazo de entrega do TCC. Abaixo está a estrutura com durações sugeridas.

## Visão Geral

| Sprint | Foco | Duração Sugerida | Meta |
|--------|------|-----------------|------|
| **Sprint 1** | Planejamento + Setup | 1 semana | Requisitos documentados, repo inicializado, diagrama de arquitetura pronto |
| **Sprint 2** | Implementação Core | 1–2 semanas | Infraestrutura deployada e funcional (API GW → Lambda → DynamoDB) |
| **Sprint 3** | Qualidade + Documentação | 1 semana | Testes, segurança validada, custos estimados, demo preparada |
| **Sprint 4** | Apresentação | 1 semana | Slides prontos, ensaio feito, equipe preparada para perguntas |

---

## Sprint 1 — Planejamento e Setup

**Objetivo:** Todos entendem o problema, a arquitetura está desenhada, e o repositório está pronto para desenvolvimento.

### Itens do Backlog

| ID | Tarefa | Responsável | Status |
|----|--------|-------------|--------|
| 1.1 | Documentar entendimento do problema | M1 | To Do |
| 1.2 | Levantar requisitos funcionais | M1 | To Do |
| 1.3 | Levantar requisitos não funcionais | M1 | To Do |
| 1.4 | Mapeamento requisito ↔ serviço AWS | M1 + M5 | To Do |
| 1.5 | Definir Definition of Done | M1 + M5 | To Do |
| 2.1 | Criar diagrama de arquitetura | M2 | To Do |
| 2.2 | Inicializar projeto Terraform | M2 | To Do |
| 2.6 | Configurar .gitignore e repo | M2 | To Do |

### Critérios de Aceitação da Sprint
- [ ] Documento de requisitos revisado por todos
- [ ] Diagrama de arquitetura aprovado pelo grupo
- [ ] Projeto Terraform inicializado (`terraform init` e `terraform validate` sem erros)
- [ ] Todos os membros com ambiente configurado (AWS CLI, Terraform, credenciais)

---

## Sprint 2 — Implementação Core

**Objetivo:** A solução está deployada na AWS e funcionando end-to-end. Pode-se clicar na API e ver o contador incrementar.

### Itens do Backlog

| ID | Tarefa | Responsável | Status |
|----|--------|-------------|--------|
| 2.3 | Configuração Terraform principal (todos os recursos) | M2 + M3 + M4 | To Do |
| 2.4 | Configurar outputs do Terraform | M2 | To Do |
| 2.5 | Documentar processo de deploy | M2 | To Do |
| 3.1 | Implementar função Lambda | M3 | To Do |
| 3.2 | Configurar API Gateway | M3 + M2 | To Do |
| 3.3 | Configurar CORS | M3 | To Do |
| 3.4 | Endpoint GET para consultar total | M3 | To Do |
| 4.1 | Criar tabela DynamoDB | M4 | To Do |
| 4.2 | Configurar IAM Role (least privilege) | M4 | To Do |
| 4.3 | Documentar estratégia de segurança | M4 | To Do |
| 4.4 | Encryption at rest DynamoDB | M4 | To Do |
| 4.5 | Avaliar necessidade de VPC | M4 | To Do |
| 5.1 | Documentar escalabilidade de cada serviço | M5 | To Do |

### Critérios de Aceitação da Sprint
- [ ] `terraform apply` executa sem erros
- [ ] Requisição POST à API incrementa o contador
- [ ] Requisição GET à API retorna o total de acessos
- [ ] IAM Role com permissões mínimas (não usa `*`)
- [ ] Todos os recursos com tags (Project, Environment, ManagedBy)

---

## Sprint 3 — Qualidade, Custos e Demo

**Objetivo:** A solução está validada, custos estimados, monitoramento ativo, e demo pronta para a apresentação.

### Itens do Backlog

| ID | Tarefa | Responsável | Status |
|----|--------|-------------|--------|
| 3.5 | Testes unitários da Lambda | M3 | To Do |
| 3.6 | Documentar endpoints | M3 | To Do |
| 4.6 | Backup DynamoDB (PITR) | M4 | To Do |
| 5.2 | Identificar gargalos | M5 | To Do |
| 5.3 | Estimativa de custos (Pricing Calculator) | M5 | To Do |
| 5.4 | Documentar resiliência | M5 | To Do |
| 5.5 | Plano de otimização de custos | M5 | To Do |
| 6.1 | Preparar demo funcional | M6 + M3 | To Do |
| 6.2 | CloudWatch Logs | M2 | Done |
| 6.3 | CloudWatch Dashboard | M6 | To Do |
| 6.4 | CloudWatch Alarm | M6 | To Do |
| 6.8 | Access logs do API Gateway | M6 | To Do |
| 6.5 | Documentar recuperação | M6 + M4 | To Do |
| 6.6 | Propor melhorias futuras | M6 | To Do |
| 6.7 | Criar a página de demonstração | M7 | To Do |
| 6.9 | Hospedar a página no S3 | M7 | To Do |
| 7.1 | Criar estrutura dos slides | M1 | To Do |

### Critérios de Aceitação da Sprint
- [ ] Testes passando
- [ ] Estimativa de custos para 3 cenários documentada
- [ ] CloudWatch Dashboard funcionando
- [ ] Demo executada com sucesso pelo menos 3 vezes
- [ ] Estrutura dos slides criada

---

## Sprint 4 — Apresentação Final

**Objetivo:** Slides finalizados, ensaio realizado, equipe preparada para perguntas da banca.

### Itens do Backlog

| ID | Tarefa | Responsável | Status |
|----|--------|-------------|--------|
| 7.2 | Slides 1–4 (Capa → Visão Geral) | M1 | To Do |
| 7.3 | Slide 5 (Arquitetura) | M2 | To Do |
| 7.4 | Slide 6 (Serviços AWS) | M3 + M4 | To Do |
| 7.5 | Slide 7 (Justificativa) | M2 + M4 | To Do |
| 7.6 | Slide 8 (Requisitos) | M1 + M5 | To Do |
| 7.7 | Slides 9–10 (Escalabilidade/Resiliência) | M5 | To Do |
| 7.8 | Slide 11 (Segurança) | M4 | To Do |
| 7.9 | Slide 12 (Custos) | M5 | To Do |
| 7.10 | Slide 13 (Recuperação) | M6 + M4 | To Do |
| 7.11 | Slide 14 (Demo) | M6 | To Do |
| 7.12 | Slides 15–16 (Diferenciais/Conclusão) | M6 + M1 | To Do |
| 7.13 | Ensaio geral | Todos | To Do |
| 7.14 | Preparação para perguntas | Todos | To Do |
| 7.15 | Revisão final + checklist | M1 + M5 | To Do |

### Critérios de Aceitação da Sprint
- [ ] Todos os 16 slides finalizados
- [ ] Cada membro ensaiou sua parte pelo menos 2 vezes
- [ ] Apresentação cabe em 10–15 minutos
- [ ] Cada membro consegue responder perguntas da sua área
- [ ] Checklist final de entrega todo marcado
