# Handoffs

Registro de entregas entre membros: o que foi feito, decisões tomadas, o que ficou
pendente e quem é impactado. Entradas mais recentes no topo.

---

## 2026-10-28 — Frontend vai para o S3 (novo membro M7) + guias de testes

**Responsável:** Eliel Delfino (M2)
**Para:** **M7** (novo integrante, Frontend), **M3** (testes) e **M4** (revisão do PR #4)

### Contexto

Decidiu-se hospedar a página de demonstração no S3 e entregar a tarefa a um novo integrante
(**M7**). A pasta `frontend/` saiu da `main` para ele refazer a página. A versão antiga continua no
histórico: `git show 3c38aad:frontend/index.html`.

### O que mudou

- **Removido:** `frontend/` (página de demonstração e README). Substitui a entrada de 23/10
  "Página de demonstração", cujo escopo "só local, melhoria futura" deixa de valer.
- **IAM pronto (M2):** statement `S3FrontendBucket` em `boot-strap/policy_project.tf`, restrito a
  buckets `contador-acessos-*-frontend-*`. O M7 **não** escreve IAM. O bootstrap ainda não foi
  aplicado, então a mudança não gera custo.
- **Guias novos:** [guia-frontend-s3.md](guia-frontend-s3.md) (M7), [`backend/README.md`](../backend/README.md)
  (M3: testes, CI, checkov e CMK) e o treinamento interativo em três artefatos Claude (M3: <https://claude.ai/artifact/SKWZqYv3ThgguKBN6qMhHS>; M6: <https://claude.ai/artifact/BngFLmqDmkytPenpKCtBtz>; M7: <https://claude.ai/artifact/JnH5hJQ5csrgm8eqnv6zCj>).
- **Backlog:** 6.7 reatribuída ao M7 (sem teste de concorrência por ora); nova 6.9 (hospedar no S3).
  Equipe de 7 pessoas.

### Decisões

- Hospedagem: **S3 website (HTTP)**. CloudFront/HTTPS continua como melhoria futura (6.6).
- `allowed_origin` passará a ser a origem do site; o `config.js` é gerado na CI para evitar ciclo
  de dependência entre o módulo `frontend` e a API.
- Criptografia do DynamoDB: chave de propriedade da AWS. O PR #4 documenta "AES256" mas configura
  `enabled = true` (chave gerenciada pela AWS); ele volta para o M4 corrigir (task 4.4).
- Fora do escopo por ora: teste de concorrência e testes `.tftest.hcl`.

### Pendente

- M7: página, módulo `infra/modules/frontend`, deploy e ajuste do CORS (tasks 6.7 e 6.9).
- M3: testes unitários, `pytest` e checkov na CI (task 3.5).
- M4: refazer o PR #4 e registrar `docs/decisao-criptografia-dynamodb.md`.
- **Não validado:** nada foi testado na AWS (bootstrap não aplicado). Os exemplos de teste e de
  módulo foram validados localmente (`pytest`, `terraform validate`, `checkov`).

---

## 2026-10-23 — Troca de integrante no papel M6 + preparação da observabilidade

**Responsável:** Eliel Delfino (M2)
**Para:** novo integrante no papel **M6** (Demonstração e Diferenciais)

### Contexto

O integrante anterior do M6 saiu do grupo e do curso. Um novo integrante assume o papel com o
mesmo identificador (M6). Para que ele comece sem depender de mudanças em outras áreas, a parte
de CloudWatch foi organizada como a do M4: **módulo em branco + guia + ganchos prontos**.

### O que foi preparado

| Item | Situação |
|---|---|
| `infra/modules/observability/` | `.tf` **em branco** + [README-guia](../infra/modules/observability/README.md) (dashboard, alarme com SNS e access logs) |
| `infra/main.tf` | `module "observability"` já chamado (vazio) e placeholder `apigw_access_log_group_arn` com `TODO(M6)` |
| `modules/api-gateway` | Access logs no stage ativados automaticamente quando recebe o ARN; formato **sem IP nem user agent**; novo output `rest_api_name` |
| `infra/variables.tf` + workflow | Variável `alarm_email` (`sensitive`), alimentada pelo secret opcional `ALARM_EMAIL` |
| `boot-strap/policy_project.tf` | Permissões para dashboard, alarme, SNS, log group `/aws/apigateway/contador-acessos-*`, `/account` do API Gateway, `AttachRolePolicy` limitado à policy `AmazonAPIGatewayPushToCloudWatchLogs` e `PassRole` para o API Gateway; tudo restrito ao prefixo `contador-acessos-*` |

**Validado (sem AWS):**

- `fmt` e `validate` nos dois diretórios;
- plan offline do estado atual: continua com **18 recursos**, stage sem access logs;
- plan offline com uma implementação mínima seguindo o guia: **26 recursos** (25 sem e-mail),
  stage com `access_log_settings`, sem ciclo de dependência, e-mail só como `(sensitive value)`;
- policy inline da role com ~3,3 mil caracteres (limite do IAM: 10.240).

**Não validado:** apply real (o bootstrap ainda não foi aplicado na AWS).

### Impacto em custo

A estimativa em [arquitetura.md](arquitetura.md#estimativa-de-custos-região-us-east-1) foi
revisada para incluir a observabilidade e corrigir o preço do DynamoDB on-demand (agora
US$ 0,625 por milhão de gravações, a metade do valor antigo).

- **Fixo:** dashboard (US$ 3,00/mês) + alarme (US$ 0,10/mês) ≈ **US$ 3,10/mês**, ou **US$ 0** se
  a conta estiver dentro das cotas gratuitas (3 dashboards e 10 alarmes).
- **Variável:** access logs somam ~0,25 KB por acesso; logs dentro da cota de 5 GB/mês até ~8
  milhões de acessos.
- **Total a 1 milhão de acessos/mês:** ~US$ 4,13 com as cotas gratuitas, ~US$ 7,76 sem elas.
- **M5:** usar esses números como base da task 5.3 (Pricing Calculator) e do slide 12. O
  dashboard é o maior custo fixo, e vale mencionar na banca.

### Tasks do novo M6

| Task | Situação |
|---|---|
| 6.2 CloudWatch Logs da Lambda | **Concluída** (M2, no módulo `lambda`) |
| 6.3 Dashboard | A fazer, pelo guia do módulo `observability` |
| 6.4 Alarme (com SNS) | A fazer, pelo guia do módulo `observability` |
| 6.8 Access logs do API Gateway (nova) | A fazer, pelo guia do módulo `observability` |
| 6.1 Demo funcional | A fazer. A página sai do S3 (M7, tasks 6.7 e 6.9); até lá, a demo usa `curl` |
| 6.5 Estratégia de recuperação | A fazer (com o M4) |
| 6.6 Melhorias futuras | A fazer |
| Slides 13–16 (7.10–7.12) | A fazer |

### Pendências

- [ ] **Reaplicar o `boot-strap`** com as novas permissões (ou aplicá-lo pela primeira vez, que é a situação atual)
- [ ] Criar o secret `ALARM_EMAIL` no GitHub (opcional)
- [ ] Novo M6: implementar o módulo seguindo o guia
- [ ] Atualizar o board (Notion/Jira) com a troca de integrante e a task 6.8

---

## 2026-10-23 — Página de demonstração (frontend)

**Responsável:** Eliel Delfino (M2)
**Task:** 6.7 (nova no backlog)
**Arquivos:** `frontend/index.html`, `frontend/README.md`

### Contexto

O case pede só o backend do contador. A página "Em Breve" é do cliente, e o repositório não
tinha nenhum frontend. Sem uma página, a demo dependeria de `curl`/Postman, e o CORS
configurado na API nunca seria testado por um navegador. A página resolve as duas coisas.

### O que a página faz

- Ao abrir, envia `POST /count` (registra um acesso) e mostra o total.
- Painel para a banca: botões `POST`/`GET`, log com status e latência e **teste de
  concorrência** (N `POST` simultâneos, confere se o total subiu exatamente N; RNF-04).
- Explica cada erro conforme a arquitetura: `500` (tabela ainda não existe), `429`
  (throttling), `403` (rota errada), rede/CORS.
- O `POST` envia `Content-Type: application/json` de propósito, para forçar o preflight
  `OPTIONS` e testar todo o CORS.
- A URL da API é informada na página ou via `?api=` e fica salva só no navegador. **Nenhuma
  URL de conta vai para o código.**

### Validado

Contra uma API **simulada** (mesmo contrato: rotas, status, headers CORS e contador atômico),
em origens diferentes:

| Cenário | Resultado |
|---|---|
| Abertura da página | `POST` → 200, total exibido |
| Preflight CORS entre origens | Respondido; `POST` aceito |
| Concorrência (N = 20) | 155 → 175: 20 aceitas, nenhum incremento perdido |
| API devolvendo 500 | Erro explicado na tela; o total não mostra número falso |

**Não validado:** a API real (depende do bootstrap, do primeiro apply e da tabela do M4).

### Escopo

A página é **só para demonstração local** (`python3 -m http.server 8000 --directory frontend`).
Ela não é implantada pela pipeline nem faz parte do Terraform. Hospedá-la na AWS
(S3 + CloudFront) continua como melhoria futura (task 6.6).

### Impacto

- **M6 (Demo):** usar a página na apresentação: o contador subindo na tela e o teste de
  concorrência. O README da página saiu da `main` em 28/10 e está no histórico
  (`git show 3c38aad:frontend/README.md`).
- **M4:** depois que a tabela existir, a página é o jeito mais rápido de validar ponta a ponta.

---

## 2026-10-23 — Estrutura Terraform + pipeline CI/CD (EPIC 2)

**Responsável:** Eliel Delfino (M2)
**Branch:** `dev` (ainda sem commit)
**Tasks:** 2.2 (inicializar Terraform), 2.3 (recursos, exceto DynamoDB), 2.4 (outputs), 2.5
(documentação de deploy), 2.6 (organização)
**Referência de estrutura:** repositório `iac-eks-platform` (boot-strap + raiz Terraform +
módulos com README)

### Status

| Item | Status |
|------|--------|
| `boot-strap/` (bucket de state, OIDC, role da pipeline) | Criado e validado localmente; **não aplicado na AWS** |
| `infra/` raiz + módulos `lambda` e `api-gateway` | Criados e validados; **não aplicados na AWS** |
| `infra/modules/dynamodb/` | **Em branco**, com guia no README → **M4** |
| `.github/workflows/terraform.yml` | Criado e aprovado pelo `actionlint`; **ainda não rodou no GitHub** |
| `.terraform.lock.hcl` (boot-strap e infra) | Gerado para linux_amd64, darwin_amd64, darwin_arm64 e windows_amd64; `terraform init` não o altera |

**Validado:**

- `terraform fmt -check` e `terraform validate` nos dois diretórios.
- `plan` **offline** (cópia descartável, sem AWS): 18 recursos no estado atual. Na simulação
  com o DynamoDB preenchido, 20 recursos (tabela + policy da Lambda), sem erro de `count`.

**Não validado:** permissões reais da role (só um plan/apply real na AWS mostra), execução
da pipeline e teste com `curl`.

### Decisões

| Decisão | Motivo |
|---------|--------|
| Pipeline igual à referência: push na `main` → plan; apply/destroy só manuais | Controle explícito sobre quando a infra muda |
| Workflow na raiz (`.github/workflows/`) | Na referência ele está em `kunlatek-infra/.github/` e nunca dispara |
| Autenticação OIDC; trust só para a `main` e o Environment `dev` | Sem chaves no GitHub; PRs e outras branches não assumem a role |
| `apply`/`destroy` exigem `github.ref == main` e o Environment `dev` restrito à `main` | O token OIDC de um job com environment não identifica a branch |
| Policy da role restrita a recursos `contador-acessos-*` | Menor privilégio, em vez de `*FullAccess` |
| OIDC provider criado pelo bootstrap (com toggle) | Sem ARN de conta fixo no código |
| Bucket fora do `backend.tf` (`-backend-config`) | O código não fica preso ao bucket de uma conta |
| Lock nativo do S3 (`use_lockfile`) | Dispensa uma tabela DynamoDB de lock |
| `apply` usa `plan -out` + `apply tfplan` | Aplica exatamente o plano mostrado no log |
| `init` sem `-upgrade` e lock versionado multi-plataforma | Mesmas versões de provider no CI e em todas as máquinas |
| DynamoDB com placeholder (`locals` vazios) | A pipeline fica verde; API + Lambda sobem e respondem 500 até a tabela existir |
| Policy do DynamoDB condicionada ao **nome** da tabela, não ao ARN | O ARN só existe após o apply e quebraria o `count` no plan |
| `archive_file` exclui `__pycache__` e `*.pyc` | Evita hash diferente entre máquinas e updates falsos da Lambda |
| Sem Makefile | Decisão do grupo: comandos `terraform` diretos |

### Impacto em outros membros

- **M4 (Dados e Segurança):** implementar `infra/modules/dynamodb/` seguindo o
  [guia](../infra/modules/dynamodb/README.md) (tasks 4.1, 4.4 e 4.6). O guia traz o contrato com a
  Lambda, os outputs obrigatórios, as 2 linhas a trocar na raiz e um checklist de PR. A IAM da
  Lambda já está pronta e é criada automaticamente.
- **M3 (Backend):** o handler não mudou. Qualquer mudança no contrato (`id`, `hits`, `count`)
  precisa ser combinada com o M4.
- **M6 (Demo):** o resumo do job de `apply` mostra o `count_endpoint`.

### Pendências

- [ ] Rodar o `boot-strap` na conta AWS do projeto (credenciais de administrador)
- [ ] Configurar no GitHub: secret `AWS_ROLE_ARN`, variables `TF_STATE_BUCKET` e `AWS_REGION`, e o
      Environment `dev` restrito à `main`
- [ ] Primeiro push na `main` e `apply` manual para validar as permissões da role
- [ ] M4: módulo DynamoDB
- [ ] Code review por outro membro e commit

---

## 2026-10-23 — Troca de IaC: AWS CDK → Terraform (EPIC 2)

**Responsável:** Eliel Delfino (M2)
**Branch:** `dev` (ainda sem commit)
**Tasks afetadas:** 2.2, 2.3, 2.4, 2.5, 2.6

### Decisão

A infraestrutura como código passa a ser feita em **Terraform**, e não mais em AWS CDK.
O case sugere CDK, mas **o instrutor autorizou a troca**. Motivos: familiaridade do grupo
com a ferramenta e organização do código.

### O que foi removido

- `infra/`: o projeto CDK inteiro (app, stack, `cdk.json`, testes da stack e requirements).
- `docs/deploy.md`: o guia de `cdk deploy`. O novo guia de deploy entra na task 2.5,
  depois que a estrutura Terraform existir.

### O que foi mantido

- `backend/contador/handler.py`: o código da Lambda não depende do CDK. Ele lê
  `TABLE_NAME`, `COUNTER_ID` e `ALLOWED_ORIGIN` de variáveis de ambiente, que o
  Terraform terá de definir na função.
- `docs/arquitetura.svg` e `docs/fluxo-contador.gif`: foram regenerados com Terraform no
  lugar do CDK.
- `.gitignore`: a seção do CDK virou uma seção de Terraform (state, `.terraform/`,
  `*.tfvars`, planos salvos). O `.terraform.lock.hcl` **deve** ser versionado.

### Documentos atualizados

`README.md`, `backlog.md`, `sprints.md`, `definition-of-done.md`, `checklist-entrega.md`,
`equipe-scrum.md`, `notion-board-setup.md`, `projeto-overview.md`, `jira-import.csv` e
`Levantamento_Requisitos_Contador_de_Acessos_AWS.md` (RNF-08 e a questão em aberto
sobre IaC, agora marcada como decidida).

Na Definition of Done, `cdk synth`/`cdk deploy` deram lugar a `terraform fmt -check` +
`terraform validate` e `terraform plan` revisado + `terraform apply`.

### Requisitos herdados para a implementação em Terraform

Estas decisões de arquitetura foram tomadas na versão CDK e continuam válidas, porque não
dependem da ferramenta:

| Requisito | Motivo |
|-----------|--------|
| DynamoDB on-demand, PK `id` (S), criptografia gerenciada pela AWS, PITR habilitado | Volume incerto sem capacidade ociosa; restauração do contador (task 4.6) |
| Lambda Python 3.13, arm64, 128 MB, timeout de 5 s | Graviton é cerca de 20% mais barato; a lógica é uma única chamada ao DynamoDB |
| Log group explícito com retenção de 14 dias | Logs sem retenção acumulam custo indefinidamente |
| Role da Lambda só com `dynamodb:UpdateItem` e `dynamodb:GetItem` no ARN da tabela | Menor privilégio (RNF-03) |
| API Gateway REST regional, `GET /count` e `POST /count`, integração proxy | Contrato já documentado em [arquitetura.md](arquitetura.md) |
| CORS com origem configurável | A página chama a API direto pelo navegador |
| Throttling no stage (50 req/s, burst 100) | Endpoint público: limita o custo em caso de abuso |
| Tags `Project`, `Environment`, `ManagedBy` em todos os recursos | Rastreio de custos no Cost Explorer |
| Outputs: URL do endpoint `/count`, nome da tabela, nome da função e log group | Usados na demo e na documentação (task 2.4) |
| Ambiente de dev fácil de destruir por completo | Não deixar custo residual depois da demo |

### Pendências

- [ ] Definir a estrutura do projeto Terraform: diretórios, módulos, state e ambientes (task 2.2)
- [ ] Implementar os recursos (2.3) e os outputs (2.4)
- [ ] Escrever o guia de deploy com Terraform (2.5)
- [ ] Code review por outro membro
- [ ] Commit na branch `dev`
- [ ] Decidir sobre o `CLAUDE.local.md`: ele está versionado desde o primeiro commit; parar de versionar exige `git rm --cached CLAUDE.local.md`
- [ ] Atualizar o board do Notion e o Jira, se o CSV já tiver sido importado

---

## 2026-10-23 — Infraestrutura CDK (EPIC 2) — *substituída*

**Responsável:** Eliel Delfino (M2)

Foi implementado um projeto AWS CDK em Python: a stack com DynamoDB, Lambda, IAM, API
Gateway e outputs, mais 8 testes da stack e um guia de deploy. O `cdk synth` passava, mas o
projeto nunca foi para a AWS nem foi commitado. Ele foi removido na entrada acima, na troca
para Terraform. As decisões de arquitetura foram preservadas na tabela "Requisitos
herdados".
