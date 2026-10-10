# Visão Geral do Projeto

## Case: Contador de Acessos Serverless

**Cliente:** Startup de marketing lançando campanha para novo produto.

**Problema:** Precisam de um contador simples na página "Em Breve" que mostre quantas pessoas já se interessaram. Não sabem se terão 10 ou 1 milhão de acessos — precisa escalar automaticamente e ser barato.

**Solução:** Arquitetura serverless na AWS.

## Serviços AWS Envolvidos

| Serviço | Papel na Solução |
|---------|-----------------|
| **Amazon API Gateway** | Porta de entrada — recebe o clique/requisição do usuário |
| **AWS Lambda** | Lógica de negócio — recebe o evento do API Gateway e incrementa o contador |
| **Amazon DynamoDB** | Banco de dados — armazena o número total de acessos |
| **AWS IAM** | Permissões entre serviços (Lambda → DynamoDB) |

## Pontos de Atenção

- **IAM:** Lambda precisa de permissão `PutItem`/`UpdateItem` na tabela DynamoDB. Por padrão, nada conversa com nada na AWS.
- **DynamoDB:** Necessita Partition Key. Para contador simples, usar chave fixa como `"id": "hits"`.
- **CDK:** Usar Python ou TypeScript (o que for mais confortável para o grupo).

## Pilares de Avaliação (10)

1. Entendimento do problema
2. Explicação das ferramentas AWS
3. Justificativa da solução
4. Atendimento aos requisitos
5. Arquitetura da solução
6. Escalabilidade e resiliência
7. Segurança
8. Custos e otimização
9. Replicação e recuperação
10. Diferenciais e prontidão para o mercado

## Apresentação

- **Duração:** 10–15 minutos + perguntas da banca
- **Formato:** 16 slides (estrutura tipo Hackathon)
- **Regra de ouro:** A banca deve conseguir responder: (1) Qual problema resolveram? (2) Como a solução resolve? (3) Por que essa foi a melhor escolha?
