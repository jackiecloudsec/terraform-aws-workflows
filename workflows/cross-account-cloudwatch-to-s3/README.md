# Cross-Account CloudWatch → Firehose → Lambda → S3

Centralizes CloudWatch logs from multiple AWS accounts into a single S3 bucket.

## Architecture

```
Source Account(s)                    Central (Security) Account
┌──────────────────┐                ┌─────────────────────────────────────┐
│ CloudWatch Logs  │                │                                     │
│                  │── subscription ──▶ Kinesis Firehose                  │
│ /aws/lambda/app  │    filter      │       │                             │
│ /aws/ecs/service │                │       ▼ (optional)                  │
└──────────────────┘                │  Lambda Transform                   │
                                    │       │                             │
                                    │       ▼                             │
                                    │  S3 Bucket                          │
                                    │  └── cloudwatch-logs/               │
                                    │      └── account=111.../            │
                                    │          └── year=2026/month=03/... │
                                    └─────────────────────────────────────┘
```

## Usage

```hcl
module "central_logging" {
  source = "../../workflows/cross-account-cloudwatch-to-s3"

  prefix             = "central-logging"
  s3_bucket_name     = "myorg-centralized-logs"
  source_account_ids = ["111111111111", "222222222222"]

  source_log_groups = {
    "app-prod" = "/aws/lambda/my-app-prod"
  }

  enable_lambda_transform = true

  tags = {
    Environment = "security"
  }
}
```

## Resources Created

- S3 bucket (versioned, encrypted, lifecycle policy)
- Kinesis Firehose delivery stream
- Lambda function (log transformation — decode gzip, flatten to JSON lines)
- IAM roles: Firehose delivery, Lambda execution, cross-account CW subscription
- CloudWatch log groups for Firehose and Lambda
