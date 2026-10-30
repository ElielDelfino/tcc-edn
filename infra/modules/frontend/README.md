# Módulo frontend (M7)

Bucket S3 configurado como site estático (HTTP) para a página do contador.

- **Guia com o código dos três arquivos** (`variables.tf`, `main.tf`, `outputs.tf`) e a explicação de
  cada recurso: [`docs/guia-frontend-s3.md`](../../../docs/guia-frontend-s3.md), Passo 2.
- Arquivos da página: [`frontend/`](../../../frontend/README.md).
- Valide sem AWS: `terraform fmt -check` e `terraform init -backend=false && terraform validate`.
  Não rode `plan` nem `apply` antes da hora do teste.
