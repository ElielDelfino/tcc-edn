output "function_name" {
  value       = aws_lambda_function.this.function_name
  description = "Nome da função Lambda"
}

output "function_arn" {
  value       = aws_lambda_function.this.arn
  description = "ARN da função Lambda"
}

output "invoke_arn" {
  value       = aws_lambda_function.this.invoke_arn
  description = "ARN de invocação — usado na integração do API Gateway"
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.this.name
  description = "Log group da função no CloudWatch"
}

output "role_name" {
  value       = aws_iam_role.this.name
  description = "Nome da role de execução da função"
}
