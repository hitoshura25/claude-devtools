# TFLint Configuration

## Installation

```bash
# macOS
brew install tflint

# Linux
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
```

## Configuration File

Create `.tflint.hcl` in your Terraform root:

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Naming conventions
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Required providers version
rule "terraform_required_providers" {
  enabled = true
}

# Required terraform version
rule "terraform_required_version" {
  enabled = true
}

# Documented variables
rule "terraform_documented_variables" {
  enabled = true
}

# Documented outputs
rule "terraform_documented_outputs" {
  enabled = true
}
```

## AWS Plugin Rules

Install the AWS ruleset:

```bash
tflint --init
```

Key AWS rules:
- `aws_instance_invalid_type` - Invalid EC2 instance type
- `aws_instance_previous_type` - Deprecated instance type
- `aws_db_instance_invalid_type` - Invalid RDS instance type
- `aws_s3_bucket_invalid_acl` - Invalid S3 ACL

## Running TFLint

```bash
# Run in current directory
tflint

# Run with specific config
tflint --config .tflint.hcl

# Run on specific directory
tflint terraform/

# Output as JSON
tflint --format json
```

## Suppressing Rules

Inline suppression:

```hcl
# tflint-ignore: aws_instance_previous_type
resource "aws_instance" "legacy" {
  instance_type = "t2.micro"  # Legacy requirement
}
```

Config suppression:

```hcl
rule "aws_instance_previous_type" {
  enabled = false
}
```
