# VPC Flow Logs → S3 → Athena

Enables VPC flow logs in Parquet format with hourly Hive partitions, creates a Glue table for Athena queries, and includes saved queries for common investigations.

## Architecture

```
┌──────────┐     ┌───────────────┐     ┌─────────┐     ┌──────────┐
│  VPC(s)  │────▶│  S3 Bucket    │────▶│  Glue   │────▶│  Athena  │
│  Flow    │     │  (Parquet,    │     │  Table  │     │  Queries │
│  Logs    │     │   hourly)     │     │         │     │          │
└──────────┘     └───────────────┘     └─────────┘     └──────────┘
```

## Saved Queries

- **rejected-traffic-last-24h** — Rejected flows by source/dest, sorted by bytes
- **top-talkers-by-bytes** — Highest-bandwidth connections
- **ssh-rdp-connections** — SSH/RDP access over last 7 days
- **potential-port-scans** — Sources hitting 20+ unique ports in the last hour

## Usage

```hcl
module "flow_logs" {
  source = "../../workflows/vpc-flow-logs-athena"

  prefix         = "network"
  vpc_ids        = ["vpc-0abc123def456"]
  s3_bucket_name = "myorg-vpc-flow-logs"
}
```
