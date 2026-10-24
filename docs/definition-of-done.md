# Definition of Done (DoD)

Uma tarefa só é considerada **Done** quando atender todos os critérios abaixo aplicáveis ao seu tipo.

## Tarefas de Código/Infraestrutura

- [ ] Código funciona localmente ou na AWS
- [ ] `terraform fmt -check` e `terraform validate` passam sem erros (se alterou Terraform)
- [ ] `terraform plan` revisado e `terraform apply` executa com sucesso (se alterou infraestrutura)
- [ ] Testado manualmente (requisição real à API)
- [ ] Sem credenciais ou segredos no código
- [ ] Commit feito com mensagem descritiva
- [ ] Outro membro revisou (code review básico)

## Tarefas de Documentação

- [ ] Conteúdo revisado por pelo menos 1 outro membro
- [ ] Informações técnicas validadas (nomes de serviços, valores, comandos)
- [ ] Sem erros de português ou informações genéricas/vagas

## Tarefas de Slides

- [ ] Conteúdo aprovado pelo PO (M1)
- [ ] Visual limpo e legível (sem texto demais)
- [ ] Consistente com os outros slides (fonte, cores, layout)
- [ ] Membro responsável ensaiou sua fala

## Geral

- [ ] Atualizado no board do Notion (status = Done)
- [ ] Dependências comunicadas (se outra tarefa dependia desta)
