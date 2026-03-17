# AWS Config → SNS Compliance Alerting

Enables AWS Config with 16 managed rules covering S3, IAM, encryption, network security, and logging. Non-compliant resources trigger SNS alerts via EventBridge.

## Architecture

```
┌──────────────┐     ┌───────────────┐
│  AWS Config  │────▶│  S3 Bucket    │  (snapshots + history)
│  Recorder    │     └───────────────┘
└──────┬───────┘
       │ 16 managed rules
       ▼
┌──────────────┐     ┌──────────────┐     ┌───────────┐     ┌──────────┐
│ Config Rules │────▶│ EventBridge  │────▶│  SNS      │────▶│  Email   │
│ NON_COMPLIANT│     │              │     │  Topic    │     │  Alerts  │
└──────────────┘     └──────────────┘     └───────────┘     └──────────┘
```

## Managed Rules Included

**S3**: public read/write prohibited, encryption enabled, versioning enabled
**Encryption**: EBS volumes encrypted, RDS storage encrypted
**IAM**: root MFA, no root access keys, password policy, console MFA required
**Network**: SSH restricted, common dangerous ports blocked
**Logging**: CloudTrail enabled (single + multi-region), GuardDuty enabled, VPC flow logs enabled

## Usage

```hcl
module "config" {
  source = "../../workflows/config-compliance"

  prefix         = "compliance"
  s3_bucket_name = "myorg-config-history"
  alert_emails   = ["security@example.com"]
  enable_all_rules = true
}
```
