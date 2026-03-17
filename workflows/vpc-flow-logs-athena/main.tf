###############################################################################
# VPC Flow Logs → S3 → Athena
#
# Enables VPC flow logs delivered to S3 in Parquet format with Hive-compatible
# partitioning, then creates a Glue database + table and Athena workgroup
# for querying. Includes saved queries for common investigations.
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  tags = merge(var.tags, {
    Workflow = "vpc-flow-logs-athena"
  })
}

# ---------------------------------------------------------------------------
# S3 — flow log destination
# ---------------------------------------------------------------------------
module "flow_log_bucket" {
  source      = "../../modules/s3-bucket"
  bucket_name = var.s3_bucket_name
  versioning  = false
  kms_key_arn = var.kms_key_arn
  tags        = local.tags
}

# ---------------------------------------------------------------------------
# VPC Flow Logs
# ---------------------------------------------------------------------------
resource "aws_flow_log" "this" {
  for_each             = toset(var.vpc_ids)
  vpc_id               = each.value
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = module.flow_log_bucket.arn
  log_format           = var.log_format

  destination_options {
    file_format                = "parquet"
    hive_compatible_partitions = true
    per_hour_partition         = true
  }

  tags = merge(local.tags, { VpcId = each.value })
}

# ---------------------------------------------------------------------------
# Athena — query results bucket
# ---------------------------------------------------------------------------
module "athena_results_bucket" {
  source          = "../../modules/s3-bucket"
  bucket_name     = "${var.s3_bucket_name}-athena-results"
  versioning      = false
  lifecycle_days  = 7
  expiration_days = 30
  tags            = local.tags
}

# ---------------------------------------------------------------------------
# Glue — database + table for flow logs
# ---------------------------------------------------------------------------
resource "aws_glue_catalog_database" "flow_logs" {
  name = var.glue_database_name
}

resource "aws_glue_catalog_table" "flow_logs" {
  name          = "vpc_flow_logs"
  database_name = aws_glue_catalog_database.flow_logs.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"  = "parquet"
    "parquet.compress" = "SNAPPY"
    EXTERNAL          = "TRUE"
  }

  storage_descriptor {
    location      = "s3://${module.flow_log_bucket.bucket}/AWSLogs/${local.account_id}/vpcflowlogs/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "version"
      type = "int"
    }
    columns {
      name = "account_id"
      type = "string"
    }
    columns {
      name = "interface_id"
      type = "string"
    }
    columns {
      name = "srcaddr"
      type = "string"
    }
    columns {
      name = "dstaddr"
      type = "string"
    }
    columns {
      name = "srcport"
      type = "int"
    }
    columns {
      name = "dstport"
      type = "int"
    }
    columns {
      name = "protocol"
      type = "bigint"
    }
    columns {
      name = "packets"
      type = "bigint"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "start"
      type = "bigint"
    }
    columns {
      name = "end"
      type = "bigint"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "log_status"
      type = "string"
    }
  }

  partition_keys {
    name = "aws-account-id"
    type = "string"
  }
  partition_keys {
    name = "aws-service"
    type = "string"
  }
  partition_keys {
    name = "aws-region"
    type = "string"
  }
  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }
}

# ---------------------------------------------------------------------------
# Athena — workgroup
# ---------------------------------------------------------------------------
resource "aws_athena_workgroup" "this" {
  name = "${var.prefix}-flow-logs"

  configuration {
    result_configuration {
      output_location = "s3://${module.athena_results_bucket.bucket}/results/"
    }
    enforce_workgroup_configuration = true
    bytes_scanned_cutoff_per_query  = var.query_byte_limit
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Athena — saved queries
# ---------------------------------------------------------------------------
resource "aws_athena_named_query" "rejected_traffic" {
  name      = "rejected-traffic-last-24h"
  workgroup = aws_athena_workgroup.this.name
  database  = aws_glue_catalog_database.flow_logs.name
  query     = <<-SQL
    SELECT srcaddr, dstaddr, dstport, protocol, sum(packets) as total_packets, sum(bytes) as total_bytes
    FROM vpc_flow_logs
    WHERE action = 'REJECT'
      AND from_unixtime("start") > current_timestamp - interval '24' hour
    GROUP BY srcaddr, dstaddr, dstport, protocol
    ORDER BY total_bytes DESC
    LIMIT 100
  SQL
}

resource "aws_athena_named_query" "top_talkers" {
  name      = "top-talkers-by-bytes"
  workgroup = aws_athena_workgroup.this.name
  database  = aws_glue_catalog_database.flow_logs.name
  query     = <<-SQL
    SELECT srcaddr, dstaddr, sum(bytes) as total_bytes, sum(packets) as total_packets,
           count(*) as flow_count
    FROM vpc_flow_logs
    WHERE from_unixtime("start") > current_timestamp - interval '24' hour
    GROUP BY srcaddr, dstaddr
    ORDER BY total_bytes DESC
    LIMIT 50
  SQL
}

resource "aws_athena_named_query" "ssh_rdp_traffic" {
  name      = "ssh-rdp-connections"
  workgroup = aws_athena_workgroup.this.name
  database  = aws_glue_catalog_database.flow_logs.name
  query     = <<-SQL
    SELECT srcaddr, dstaddr, dstport, action, sum(packets) as total_packets,
           from_unixtime(min("start")) as first_seen,
           from_unixtime(max("end")) as last_seen
    FROM vpc_flow_logs
    WHERE dstport IN (22, 3389)
      AND from_unixtime("start") > current_timestamp - interval '7' day
    GROUP BY srcaddr, dstaddr, dstport, action
    ORDER BY total_packets DESC
  SQL
}

resource "aws_athena_named_query" "port_scan_detection" {
  name      = "potential-port-scans"
  workgroup = aws_athena_workgroup.this.name
  database  = aws_glue_catalog_database.flow_logs.name
  query     = <<-SQL
    SELECT srcaddr, count(distinct dstport) as unique_ports, count(distinct dstaddr) as unique_hosts,
           sum(packets) as total_packets
    FROM vpc_flow_logs
    WHERE from_unixtime("start") > current_timestamp - interval '1' hour
    GROUP BY srcaddr
    HAVING count(distinct dstport) > 20
    ORDER BY unique_ports DESC
  SQL
}
