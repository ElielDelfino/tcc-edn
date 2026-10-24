# Handoffs

Registro de entregas entre membros: o que foi feito, decisões tomadas, o que ficou
pendente e quem é impactado. Entradas mais recentes no topo.

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
  concorrência. Ver o [README](../frontend/README.md).
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
