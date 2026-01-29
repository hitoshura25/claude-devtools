# TFSec Configuration

## Installation

```bash
# macOS
brew install tfsec

# Linux
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

## Configuration File

Create `.tfsec.yml` in your repository root:

```yaml
minimum_severity: MEDIUM

exclude:
  # Exclude specific rules by ID
  # - aws-s3-enable-bucket-logging  # If centralized logging exists

severity_overrides:
  # Upgrade severity for specific rules
  aws-iam-no-policy-wildcards: CRITICAL
  aws-s3-no-public-access: CRITICAL
```

## Running TFSec

```bash
# Run in current directory
tfsec .

# Soft fail (exit 0 even with issues)
tfsec . --soft-fail

# Output as JSON
tfsec . --format json

# Exclude specific checks
tfsec . --exclude aws-s3-enable-bucket-logging

# Only show specific severity
tfsec . --minimum-severity HIGH
```

## Common Rules

| Rule ID | Description | Severity |
|---------|-------------|----------|
| `aws-s3-enable-bucket-encryption` | S3 bucket encryption | HIGH |
| `aws-s3-no-public-access` | S3 public access | CRITICAL |
| `aws-vpc-no-public-egress-sgr` | Security group egress | HIGH |
| `aws-iam-no-policy-wildcards` | IAM wildcards | CRITICAL |
| `aws-rds-encrypt-instance-storage` | RDS encryption | HIGH |

## Inline Suppression

```hcl
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "static" {
  bucket = "static-assets"
  # Logging handled by CloudFront
}
```

With expiry:

```hcl
#tfsec:ignore:aws-s3-enable-bucket-logging:exp:2025-12-31
resource "aws_s3_bucket" "temp" {
  bucket = "temporary-bucket"
}
```

## CI Integration

```yaml
- name: Run tfsec
  uses: aquasecurity/tfsec-action@b466648d6e39e7c75324f25d83891162a721f2d6 # v1.0.3
  with:
    soft_fail: false
    github_token: ${{ secrets.GITHUB_TOKEN }}
```
