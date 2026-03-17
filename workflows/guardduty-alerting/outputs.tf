output "detector_id" {
  value = aws_guardduty_detector.this.id
}

output "sns_topic_arn" {
  value = module.alert_topic.arn
}

output "eventbridge_rule_arn" {
  value = aws_cloudwatch_event_rule.critical_findings.arn
}

output "findings_bucket_arn" {
  value = var.archive_findings ? module.findings_bucket[0].arn : null
}
