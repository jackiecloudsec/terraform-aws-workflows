# terraform-aws-workflows

Production-ready Terraform templates for common AWS security and operations workflows. Each workflow is self-contained, uses shared reusable modules, and can be deployed independently.

## Workflows

| Workflow | What it deploys |
|----------|----------------|
| [**cross-account-cloudwatch-to-s3**](workflows/cross-account-cloudwatch-to-s3/) | Centralizes CloudWatch logs from multiple accounts via Kinesis Firehose + optional Lambda transform to S3 |
| [**guardduty-alerting**](workflows/guardduty-alerting/) | Enables GuardDuty with S3/EKS/malware protection, routes findings to SNS, optionally archives to S3 |
| [**centralized-cloudtrail**](workflows/centralized-cloudtrail/) | Org-wide CloudTrail → S3 + CloudWatch Logs with 8 metric-filter alarms for high-risk API calls |
| [**vpc-flow-logs-athena**](workflows/vpc-flow-logs-athena/) | VPC flow logs in Parquet → Glue table → Athena workgroup with saved hunt queries |
| [**security-hub-alerting**](workflows/security-hub-alerting/) | Security Hub (CIS, FSBP, NIST) → EventBridge → SNS alerts for critical/high findings |
| [**config-compliance**](workflows/config-compliance/) | AWS Config recorder + 16 managed rules (S3, IAM, encryption, network, logging) with SNS alerts |

## Reusable Modules

| Module | Purpose |
|--------|---------|
| `modules/iam-role` | IAM role with assume-role policy, inline policy, and managed policy attachments |
| `modules/s3-bucket` | S3 bucket with versioning, encryption, public access block, lifecycle, optional policy |
| `modules/lambda-function` | Lambda function from source dir with log group and invoke permissions |
| `modules/sns-topic` | SNS topic with email and Lambda subscriptions |
| `modules/kinesis-firehose` | Firehose delivery stream to S3 with optional Lambda transform |
| `modules/eventbridge-rule` | EventBridge rule with configurable targets and input transformers |

## Quick Start

```bash
cd workflows/guardduty-alerting
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

## Structure

```
├── modules/
│   ├── iam-role/
│   ├── s3-bucket/
│   ├── lambda-function/
│   ├── sns-topic/
│   ├── kinesis-firehose/
│   └── eventbridge-rule/
└── workflows/
    ├── cross-account-cloudwatch-to-s3/
    ├── guardduty-alerting/
    ├── centralized-cloudtrail/
    ├── vpc-flow-logs-athena/
    ├── security-hub-alerting/
    └── config-compliance/
```

Each workflow directory contains:
- `main.tf` — resources and module calls
- `variables.tf` — input variables with defaults
- `outputs.tf` — useful output values
- `terraform.tfvars.example` — example configuration
- `README.md` — architecture diagram and usage

## Requirements

- Terraform >= 1.5
- AWS provider >= 5.0
- Appropriate AWS permissions for the resources being created
