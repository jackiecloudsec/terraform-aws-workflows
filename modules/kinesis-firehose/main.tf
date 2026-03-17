resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = var.name
  destination = var.enable_lambda ? "extended_s3" : "extended_s3"
  tags        = var.tags

  extended_s3_configuration {
    role_arn            = var.role_arn
    bucket_arn          = var.s3_bucket_arn
    prefix              = var.s3_prefix
    error_output_prefix = var.s3_error_prefix
    buffering_size      = var.buffering_size_mb
    buffering_interval  = var.buffering_interval_sec
    compression_format  = var.compression_format

    dynamic "processing_configuration" {
      for_each = var.enable_lambda ? [1] : []
      content {
        enabled = true

        processors {
          type = "Lambda"

          parameters {
            parameter_name  = "LambdaArn"
            parameter_value = "${var.lambda_arn}:$LATEST"
          }

          parameters {
            parameter_name  = "BufferSizeInMBs"
            parameter_value = "1"
          }

          parameters {
            parameter_name  = "BufferIntervalInSeconds"
            parameter_value = "60"
          }
        }
      }
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = "S3Delivery"
    }
  }
}

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}
