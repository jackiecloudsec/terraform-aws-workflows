output "s3_bucket_arn" {
  value = module.flow_log_bucket.arn
}

output "glue_database" {
  value = aws_glue_catalog_database.flow_logs.name
}

output "glue_table" {
  value = aws_glue_catalog_table.flow_logs.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.this.name
}
