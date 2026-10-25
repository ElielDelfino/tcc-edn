# Documentação Técnica: Módulo DynamoDB (M4)

Este documento descreve a implementação do banco de dados para o sistema de Contador de Acessos.

## 📋 Visão Geral
O módulo é responsável pelo provisionamento de uma tabela no Amazon DynamoDB, configurada para suportar incrementos atômicos de acessos com alta disponibilidade e baixo custo.

## 🛠️ Especificações Técnicas

### 1. Configuração da Tabela
| Recurso | Configuração | Justificativa |
|---|---|---|
| **Nome** | `${var.name_prefix}-counter` | Padronização para permissões de IAM via prefixo. |
| **Chave de Partição** | `id` (Tipo: String) | Chave única para identificar o contador de hits. |
| **Modo de Cobrança** | `PAY_PER_REQUEST` | Otimização de custo para volumes incertos de tráfego (On-demand). |
| **Criptografia** | `AES256` (SSE) | Segurança dos dados em repouso conforme requisitos de segurança. |
| **Recuperação** | `PITR` Ativado | Permite a restauração de dados em qualquer ponto dos últimos 35 dias. |
| **Proteção de Exclusão**| `false` (em dev) | Facilita a destruição da infraestrutura via pipeline de CI/CD. |

### 2. Contrato de Dados
A tabela foi projetada para integrar-se perfeitamente com o handler da Lambda:
- **Item de Contador:** `id = "hits"`
- **Atributo de Valor:** `count` (Tipo: Number)
- **Operação:** Utiliza a expressão `ADD` do DynamoDB para garantir incrementos atômicos, evitando condições de corrida (race conditions).

## 🔗 Interface do Módulo

### Inputs (Variáveis)
- `name_prefix`: String utilizada para compor o nome da tabela e garantir a governança de nomes no ambiente AWS.

### Outputs (Saídas)
- `table_name`: Retorna o nome final da tabela criada.
- `table_arn`: Retorna o Amazon Resource Name (ARN) da tabela para configuração de permissões IAM da Lambda.

## ✅ Validação de Requisitos
- [x] **Custo:** Implementado modo On-Demand para evitar custos de capacidade ociosa.
- [x] **Segurança:** Criptografia em repouso habilitada.
- [x] **Resiliência:** Point-in-Time Recovery (PITR) configurado.
- [x] **Integração:** Outputs exportados e consumidos corretamente pela raiz da infraestrutura.

---
**Responsável:** Membro 4 (Dados e Segurança)
**Status:** Implementado e Validado.
