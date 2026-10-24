# Como Configurar o Board no Notion

Guia para montar o Scrum board no Notion baseado no backlog deste projeto.

## Database: Backlog (Board View)

### Propriedades da database

| Propriedade | Tipo | Valores |
|-------------|------|---------|
| **Título** | Title | Nome da tarefa |
| **Status** | Select | `To Do`, `In Progress`, `In Review`, `Done`, `Blocked` |
| **Sprint** | Select | `Sprint 1`, `Sprint 2`, `Sprint 3`, `Sprint 4` |
| **Epic** | Select | `Planejamento`, `Arquitetura/Terraform`, `Backend`, `Dados/Segurança`, `Custos/Escalabilidade`, `Demo/Diferenciais`, `Apresentação` |
| **Responsável** | Person | Membros do grupo |
| **Story Points** | Number | 1, 2, 3, 5, 8 |
| **Prioridade** | Select | `Alta`, `Média`, `Baixa` |
| **ID** | Text | 1.1, 1.2, ... (referência ao backlog) |
| **Dependências** | Relation | Link para tarefas que bloqueiam esta |
| **Notas** | Text | Observações, links para referência |

### Views recomendadas

1. **Board (Kanban)** — Agrupa por `Status`, filtra por `Sprint` atual
2. **Por Membro** — Agrupa por `Responsável`, filtra por `Sprint` atual
3. **Por Epic** — Agrupa por `Epic`, mostra todas as sprints
4. **Timeline** — View de timeline/gantt para ver dependências
5. **Burndown** — View de tabela agrupada por Sprint, com soma de SP por Status

## Database: Sprint Log

Para registrar as cerimônias e decisões.

| Propriedade | Tipo |
|-------------|------|
| **Sprint** | Select |
| **Cerimônia** | Select (`Planning`, `Daily`, `Review`, `Retro`) |
| **Data** | Date |
| **Participantes** | Person |
| **Notas** | Text (rich text) |
| **Ações** | Text |

## Páginas adicionais no Notion

- **Projeto Overview** — Copiar conteúdo de `docs/projeto-overview.md`
- **Arquitetura** — Copiar conteúdo de `docs/arquitetura.md`
- **Equipe e Papéis** — Copiar conteúdo de `docs/equipe-scrum.md`
- **Checklist de Entrega** — Copiar conteúdo de `docs/checklist-entrega.md` (usar toggle lists)
- **Referências** — Links para documentação AWS de cada serviço usado

## Dica: Template de Daily Standup

Criar um template no Notion para as dailies:

```
## Daily — [Data]

### [Nome do membro]
- **Ontem:** 
- **Hoje:** 
- **Impedimentos:** 

(repetir para cada membro)
```
