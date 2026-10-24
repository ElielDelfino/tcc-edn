output "project_role_arn" {
  description = "ARN da role do GitHub Actions — configure como secret AWS_ROLE_ARN"
  value       = aws_iam_role.project_role.arn
}

output "s3_bucket_name" {
  description = "Bucket do state remoto — configure como variable TF_STATE_BUCKET"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "s3_bucket_region" {
  description = "Região do bucket — configure como variable AWS_REGION"
  value       = aws_s3_bucket.terraform_state.region
}

output "github_oidc_provider_arn" {
  description = "ARN do OIDC provider do GitHub Actions na conta"
  value       = local.github_oidc_provider_arn
}
