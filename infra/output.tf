output "api_invoke_url" {
  value = module.api_gateway.invoke_url
}

output "count_endpoint" {
  description = "Endpoint usado pela página e pela demo (GET consulta, POST incrementa)"
  value       = module.api_gateway.count_endpoint
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "lambda_log_group_name" {
  value = module.lambda.log_group_name
}

output "frontend_bucket_name" {
  value = module.frontend.bucket_name
}

output "website_url" {
  value = module.frontend.website_origin
}

output "dashboard_name" {
  value       = module.observability.dashboard_name
  description = "Nome do painel CloudWatch"
}

output "alarm_name" {
  value       = module.observability.alarm_name
  description = "Nome do alarme de erros HTTP 5XX"
}

output "api_access_log_group_name" {
  value       = module.observability.access_log_group_name
  description = "Logs de acesso do API Gateway"
}
