# Checklist Final de Entrega

Baseado nos 10 pilares de avaliação do TCC. Marque cada item antes da apresentação.

---

## 1. Negócio
- [ ] Entendemos claramente o problema do cliente
- [ ] Identificamos todos os requisitos (funcionais e não funcionais)
- [ ] Sabemos explicar por que o cliente precisa disso

## 2. Arquitetura
- [ ] Diagrama de arquitetura completo (fluxo de acesso, dados, integrações, segurança)
- [ ] Conseguimos explicar o fluxo da aplicação do início ao fim
- [ ] Conseguimos justificar a escolha de cada serviço AWS
- [ ] Consideramos alternativas e sabemos explicar por que não foram escolhidas

## 3. Implementação
- [ ] Código da Lambda funcional e testado
- [ ] API Gateway configurado e acessível
- [ ] DynamoDB com schema correto e dados persistindo
- [ ] CDK/IaC deployando toda a infraestrutura com sucesso
- [ ] Repositório organizado (README, .gitignore, estrutura clara)

## 4. Segurança
- [ ] IAM com permissões mínimas (least privilege)
- [ ] Encryption at rest habilitada no DynamoDB
- [ ] Sem credenciais hardcoded no código
- [ ] Sabemos explicar quem pode acessar o quê

## 5. Escalabilidade
- [ ] Explicamos como cada serviço escala
- [ ] Identificamos gargalos potenciais
- [ ] Sabemos o que acontece com 10x e 100x mais usuários
- [ ] Explicamos como a solução é serverless e por que isso importa

## 6. Resiliência
- [ ] Sabemos o que acontece se uma instância/serviço falhar
- [ ] DynamoDB é Multi-AZ por padrão — sabemos explicar
- [ ] Lambda tem retry automático — sabemos explicar
- [ ] Respondemos: "A aplicação continua disponível mesmo diante de falhas?"

## 7. Custos
- [ ] Estimativa com AWS Pricing Calculator para pelo menos 3 cenários
- [ ] Sabemos quais serviços geram mais custo
- [ ] Temos estratégia de otimização documentada
- [ ] Sabemos explicar por que serverless é econômico para este caso

## 8. Recuperação
- [ ] Point-in-Time Recovery habilitado no DynamoDB
- [ ] Sabemos como recuperar a aplicação (re-deploy via CDK)
- [ ] Temos tempo estimado de recuperação
- [ ] Estratégia de backup documentada

## 9. Demonstração
- [ ] Demo funcional testada pelo menos 3 vezes
- [ ] Screenshots/evidências de backup (caso a demo falhe ao vivo)
- [ ] CloudWatch mostrando logs e métricas
- [ ] Todos os integrantes conhecem a arquitetura (não só sua parte)

## 10. Diferenciais
- [ ] Propusemos melhorias futuras (CI/CD, front-end, analytics, rate limiting)
- [ ] CloudWatch Dashboard configurado
- [ ] Alarmes configurados
- [ ] Demonstramos visão estratégica e pensamento além do mínimo

---

## Apresentação
- [ ] 16 slides completos
- [ ] Apresentação cabe em 10–15 minutos
- [ ] Cada membro ensaiou sua parte
- [ ] Cada membro sabe responder perguntas da sua área
- [ ] Slides são apoio visual — ninguém lê os slides
- [ ] Demo reservada para o meio/final da apresentação (não no último minuto)
