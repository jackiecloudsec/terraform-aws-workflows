# GuardDuty → EventBridge → SNS Alerting

Enables GuardDuty with S3/EKS/malware protection and routes high-severity findings to email via SNS. Optionally archives all findings to S3.

## Architecture

```
┌────────────┐     ┌──────────────┐     ┌───────────┐     ┌────────────┐
│ GuardDuty  │────▶│ EventBridge  │────▶│  SNS      │────▶│  Email     │
│ Detector   │     │ severity >= N│     │  Topic    │     │  Alerts    │
└────────────┘     └──────┬───────┘     └───────────┘     └────────────┘
                          │ (optional)
                          ▼
                   ┌──────────────┐     ┌───────────┐
                   │  Firehose    │────▶│  S3       │
                   │  (archive)   │     │  Archive  │
                   └──────────────┘     └───────────┘
```

## Usage

```hcl
module "guardduty" {
  source = "../../workflows/guardduty-alerting"

  prefix       = "security"
  alert_emails = ["security-team@example.com"]
  min_severity = 7

  enable_s3_protection  = true
  enable_eks_protection = true
  archive_findings      = true
}
```
