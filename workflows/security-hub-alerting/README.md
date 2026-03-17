# Security Hub → EventBridge → SNS Alerting

Enables Security Hub with compliance standards (AWS Foundational, CIS, NIST 800-53) and routes critical/high findings to email via EventBridge + SNS.

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌───────────┐     ┌──────────┐
│ Security Hub │────▶│ EventBridge  │────▶│  SNS      │────▶│  Email   │
│ (CIS, FSBP,  │     │ CRITICAL/HIGH│     │  Topic    │     │  Alerts  │
│  NIST 800-53)│     └──────┬───────┘     └───────────┘     └──────────┘
└──────────────┘            │ (optional)
                            ▼
                     ┌──────────────┐     ┌───────────┐
                     │  Firehose    │────▶│  S3       │
                     │  (archive)   │     │  Archive  │
                     └──────────────┘     └───────────┘
```

## Usage

```hcl
module "security_hub" {
  source = "../../workflows/security-hub-alerting"

  prefix       = "security"
  alert_emails = ["security@example.com"]

  enable_aws_foundational = true
  enable_cis_benchmark    = true
  archive_findings        = true
}
```
