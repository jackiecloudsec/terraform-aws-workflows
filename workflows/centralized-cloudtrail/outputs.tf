output "trail_arn" {
  value = aws_cloudtrail.this.arn
}

output "s3_bucket_arn" {
  value = module.trail_bucket.arn
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.trail.arn
}

output "sns_topic_arn" {
  value = module.alert_topic.arn
}
