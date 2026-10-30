# frontend — página do contador no S3 (M7)

Esta pasta guarda os arquivos que o navegador baixa do S3. O passo a passo completo, com o código
do módulo Terraform, o CORS e o deploy, está em **[`docs/guia-frontend-s3.md`](../docs/guia-frontend-s3.md)**.
Tasks do [backlog](../docs/backlog.md): **6.7** (a página) e **6.9** (hospedagem no S3).

## O que criar e onde

```
frontend/
├── index.html           # (você escreve) a página: POST ao abrir, GET no botão, erro legível
├── app.js               # (você escreve) chamadas POST/GET e mensagens de erro
├── config.example.js    # (você escreve) modelo: window.CONTADOR_API_URL = "COLE_A_URL_AQUI";
├── config.js            # NÃO existe no repositório: a CI gera após o apply (está no .gitignore)
├── error.html           # pagina de erro do site S3
└── README.md            # este arquivo

infra/modules/frontend/  # (você escreve) bucket do site; veja o guia, Passo 2
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```

Os arquivos foram disponibilizados inicialmente vazios e implementados no M7. Também há dois arquivos existentes para **editar** (não criar):
`infra/main.tf` e `infra/output.tf` (ligar o módulo) e `.github/workflows/terraform.yml` (deploy).

## Regras rápidas

- Nenhuma URL de conta AWS ou segredo dentro do código da página.
- Sem custo até o teste e a apresentação: valide só com `terraform fmt -check` e
  `terraform init -backend=false && terraform validate`. **Não rode `plan` nem `apply`.**
- O IAM da pipeline (`S3FrontendBucket`) já existe em `boot-strap/policy_project.tf`.
