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

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB criada"
  value       = module.dynamodb.table_name
}
