output "securityhub_account_id" {
  value = aws_securityhub_account.this.id
}

output "sns_topic_arn" {
  value = module.alert_topic.arn
}

output "eventbridge_rule_arn" {
  value = aws_cloudwatch_event_rule.critical_findings.arn
}
