output "rest_api_id" {
  value       = aws_api_gateway_rest_api.this.id
  description = "ID da REST API"
}

output "rest_api_name" {
  value       = aws_api_gateway_rest_api.this.name
  description = "Nome da REST API — dimensão ApiName das métricas do CloudWatch"
}

output "invoke_url" {
  value       = aws_api_gateway_stage.this.invoke_url
  description = "URL base do stage"
}

output "count_endpoint" {
  value       = "${aws_api_gateway_stage.this.invoke_url}/count"
  description = "Endpoint do contador (GET consulta, POST incrementa)"
}
