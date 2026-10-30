output "bucket_name" {
  description = "Nome do bucket do site (usado pelo deploy: aws s3 sync)"
  value       = aws_s3_bucket.site.id
}

output "website_origin" {
  description = "Origem do site (http://<endpoint>), sem barra no final. Vai para allowed_origin do CORS"
  value       = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}
