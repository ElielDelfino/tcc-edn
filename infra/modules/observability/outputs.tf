output "access_log_group_arn" {
  value       = aws_cloudwatch_log_group.api_access.arn
  description = "Grupo de logs de acesso do API Gateway (espera a role da conta)"
  depends_on  = [aws_api_gateway_account.this]
}

output "access_log_group_name" {
  value       = aws_cloudwatch_log_group.api_access.name
  description = "Nome do grupo para aws logs tail"
}

output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.this.dashboard_name
  description = "Dashboard para as últimas 24 horas"
}

output "alarm_name" {
  value       = aws_cloudwatch_metric_alarm.api_5xx.alarm_name
  description = "Alarme HTTP 5XX da API"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.alarms.arn
  description = "ARN do tópico usado pelo alarme"
}
