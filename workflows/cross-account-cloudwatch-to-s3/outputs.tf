output "s3_bucket_arn" {
  description = "Log destination bucket ARN"
  value       = module.log_bucket.arn
}

output "s3_bucket_name" {
  description = "Log destination bucket name"
  value       = module.log_bucket.bucket
}

output "firehose_arn" {
  description = "Firehose delivery stream ARN"
  value       = module.firehose.arn
}

output "subscription_role_arn" {
  description = "IAM role ARN for cross-account CW subscription"
  value       = module.cw_subscription_role.arn
}
