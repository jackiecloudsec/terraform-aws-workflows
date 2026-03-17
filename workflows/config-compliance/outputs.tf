output "recorder_id" {
  value = aws_config_configuration_recorder.this.id
}

output "s3_bucket_arn" {
  value = module.config_bucket.arn
}

output "sns_topic_arn" {
  value = module.alert_topic.arn
}

output "config_rule_arns" {
  value = { for k, v in aws_config_config_rule.this : k => v.arn }
}
