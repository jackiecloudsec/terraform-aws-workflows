# Centralized CloudTrail → S3 + CloudWatch Logs + Alerts

Multi-region CloudTrail with S3 archival, CloudWatch Logs streaming, and metric-filter-based alerts for high-risk API calls.

## Architecture

```
┌──────────────┐     ┌───────────────┐     ┌───────────────┐
│  CloudTrail  │────▶│  S3 Bucket    │     │  CloudWatch   │
│  (all regions│     │  (encrypted)  │     │  Log Group    │
│   org-wide)  │────▶│               │     │               │
└──────────────┘     └───────────────┘     └───────┬───────┘
                                                   │
                                           8 metric filters
                                                   │
                                           ┌───────▼───────┐
                                           │  CW Alarms    │
                                           │  → SNS → Email│
                                           └───────────────┘
```

## Metric Filter Alerts

- Unauthorized API calls
- Failed console sign-in attempts
- Root account usage
- IAM policy changes
- Network ACL changes
- Security group changes
- CloudTrail config tampering
- S3 bucket policy changes

## Usage

```hcl
module "cloudtrail" {
  source = "../../workflows/centralized-cloudtrail"

  prefix         = "central"
  s3_bucket_name = "myorg-cloudtrail-logs"
  multi_region   = true
  alert_emails   = ["security@example.com"]
}
```
