---
name: aws-scaffold
description: Gera estrutura inicial de projeto AWS (Terraform, CloudFormation ou CDK) baseado nos requisitos descritos pelo usuário. Use quando o usuário quiser iniciar uma nova infraestrutura ou módulo AWS.
disable-model-invocation: true
---

# Scaffold de Infraestrutura AWS

Quando o usuário descrever os requisitos, gere a estrutura do projeto seguindo estas diretrizes:

## 1. Entender os requisitos

Pergunte (se não especificado):
- Qual ferramenta de IaC? (Terraform, CloudFormation, CDK — se não souber, recomendar Terraform)
- Quais serviços AWS serão usados?
- Ambiente: dev/staging/prod?
- Região AWS?

Use `$ARGUMENTS` como descrição inicial dos requisitos se fornecido.

## 2. Gerar a estrutura

### Para Terraform:
```
├── main.tf          # Recursos principais
├── variables.tf     # Variáveis de entrada
├── outputs.tf       # Outputs
├── providers.tf     # Provider AWS + versão
├── terraform.tfvars.example  # Exemplo de valores
└── README.md        # Como usar
```

### Para CloudFormation:
```
├── template.yaml    # Template principal
├── parameters/
│   └── dev.json     # Parâmetros por ambiente
└── README.md
```

### Para CDK (Python ou TypeScript):
Usar `cdk init` como base e adicionar os constructs necessários.

## 3. Boas práticas obrigatórias

- Tags em todos os recursos (Project, Environment, ManagedBy)
- Variáveis para valores que mudam entre ambientes
- Outputs para valores que outros stacks/módulos precisam
- Comentários explicando decisões de arquitetura não óbvias
- `.gitignore` adequado para a ferramenta escolhida
- State remoto configurado (S3 + DynamoDB para Terraform)

## 4. Após gerar

- Explicar a arquitetura criada e o porquê de cada decisão
- Listar os pré-requisitos (AWS CLI configurado, credenciais, etc.)
- Dar os comandos para deploy inicial
