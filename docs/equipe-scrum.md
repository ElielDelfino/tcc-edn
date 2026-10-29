# Organização Scrum — Equipe de 7 Pessoas

## Papéis Scrum

| Papel | Responsabilidade | Sugestão |
|-------|-----------------|----------|
| **Product Owner (PO)** | Define prioridades, aceita entregas, garante que o produto atende os requisitos do TCC | 1 pessoa (pode acumular com outro papel técnico) |
| **Scrum Master** | Facilita cerimônias, remove impedimentos, garante que o processo Scrum funciona | 1 pessoa (pode acumular com outro papel técnico) |
| **Dev Team** | Executa as tarefas técnicas e de documentação | Todos os 7 participam |

> **Nota:** Em um grupo de 6 para TCC, o PO e o Scrum Master também executam tarefas técnicas. São papéis de coordenação, não dedicação exclusiva.

## Distribuição por Área de Responsabilidade

Cada membro é **responsável principal** por sua área, mas todos devem conhecer o projeto inteiro (a banca pode perguntar para qualquer um).

### Membro 1 — Product Owner + Negócio
- **Área:** Entendimento do problema, requisitos, visão geral da solução
- **Slides:** 1 (Capa), 2 (Problema), 3 (Requisitos), 4 (Visão Geral)
- **Tarefas técnicas:** Documentação de requisitos funcionais e não funcionais, mapeamento requisito ↔ serviço AWS
- **Na apresentação:** Abre a apresentação, contextualiza o problema e a solução

### Membro 2 — Arquitetura + Infraestrutura (Terraform)
- **Área:** Diagrama de arquitetura, Terraform/IaC, deploy
- **Slides:** 5 (Diagrama de Arquitetura)
- **Tarefas técnicas:** Projeto Terraform (recursos, variáveis, outputs), diagrama de arquitetura, CI/CD se houver
- **Na apresentação:** Explica o fluxo da arquitetura e como os serviços se conectam

### Membro 3 — Backend (Lambda + API Gateway)
- **Área:** Função Lambda, configuração do API Gateway, integração
- **Slides:** 6 (Explicação dos Serviços — Lambda e API Gateway)
- **Tarefas técnicas:** Código da Lambda (handler), configuração do API Gateway (rotas, métodos, CORS), testes de integração
- **Na apresentação:** Explica API Gateway e Lambda, o que fazem e por que foram escolhidos

### Membro 4 — Dados + Segurança
- **Área:** DynamoDB, IAM, segurança geral
- **Slides:** 6 (Explicação dos Serviços — DynamoDB), 7 (Justificativa Técnica), 11 (Segurança)
- **Tarefas técnicas:** Tabela DynamoDB (schema, partition key), políticas IAM (roles, policies), Security Groups se aplicável
- **Na apresentação:** Explica DynamoDB e toda a estratégia de segurança

### Membro 5 — Scrum Master + Escalabilidade/Custos
- **Área:** Escalabilidade, resiliência, custos, otimização
- **Slides:** 8 (Mapeamento de Requisitos), 9 (Escalabilidade), 10 (Resiliência), 12 (Custos)
- **Tarefas técnicas:** Análise de custos (AWS Pricing Calculator), configuração de Auto Scaling/reservas, análise de gargalos, documentação de como a solução escala
- **Na apresentação:** Explica como a solução cresce, reage a falhas, e quanto custa

### Membro 6 — Demonstração + Diferenciais
- **Área:** Demo funcional, backup/recuperação, evolução futura
- **Slides:** 13 (Recuperação), 14 (Demonstração), 15 (Diferenciais), 16 (Conclusão)
- **Tarefas técnicas:** Preparar demo ao vivo, configurar monitoramento (CloudWatch), propor melhorias futuras (dashboard, alarmes, CI/CD)
- **Na apresentação:** Faz a demo ao vivo e fecha com visão de futuro

### Membro 7 — Frontend (S3)
- **Área:** Página de demonstração hospedada no S3, consumindo a API do contador
- **Slides:** apoia o 14 (Demonstração) com a página no ar
- **Tarefas técnicas:** Criar a página estática, o módulo Terraform `infra/modules/frontend` (bucket do site), o deploy dos arquivos e o ajuste de CORS. O IAM da pipeline fica com o M2. Guia: [guia-frontend-s3.md](guia-frontend-s3.md)
- **Na apresentação:** Mostra a página no ar e explica como ela chega ao navegador

## Cerimônias Scrum Sugeridas

| Cerimônia | Frequência | Duração | O que fazer |
|-----------|-----------|---------|-------------|
| **Daily Standup** | Diária (ou 3x/semana) | 15 min | Cada um: o que fiz, o que vou fazer, impedimentos |
| **Sprint Planning** | Início de cada Sprint | 30–60 min | Selecionar itens do backlog, estimar, distribuir |
| **Sprint Review** | Final de cada Sprint | 30 min | Demonstrar o que foi entregue |
| **Sprint Retrospectiva** | Final de cada Sprint | 15 min | O que funcionou, o que melhorar |

## Matriz RACI por Entrega

| Entrega | M1 (PO) | M2 (Arq) | M3 (Back) | M4 (Dados) | M5 (SM) | M6 (Demo) | M7 (Front) |
|---------|---------|----------|-----------|------------|---------|-----------|------------|
| Requisitos | **R/A** | C | C | C | I | I | I |
| Arquitetura Terraform | C | **R/A** | C | C | I | I | C |
| Lambda + API GW | I | C | **R/A** | C | I | I | C |
| DynamoDB + IAM | I | C | C | **R/A** | I | I | I |
| Análise de Custos | C | I | I | I | **R/A** | C | I |
| Demo + Monitoramento | I | C | C | I | C | **R/A** | C |
| Página no S3 | I | C (IAM) | C (CORS) | I | I | C | **R/A** |
| Slides | **A** | R | R | R | R | R | R |
| Apresentação | **A** | R | R | R | R | R | R |

> **R** = Responsável (executa) · **A** = Aprovador · **C** = Consultado · **I** = Informado
