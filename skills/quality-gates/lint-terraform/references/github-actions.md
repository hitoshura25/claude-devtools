# GitHub Actions for Terraform Linting

## Complete Workflow

Create `.github/workflows/terraform-lint.yml`:

```yaml
name: Terraform Lint

on:
  pull_request:
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-lint.yml'

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd # v3
        with:
          terraform_version: "1.7.0"

      - name: Terraform Format
        run: terraform fmt -check -recursive terraform/

      - name: Terraform Init
        run: terraform -chdir=terraform/environments/dev init -backend=false

      - name: Terraform Validate
        run: terraform -chdir=terraform/environments/dev validate

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@6e87008f9dd1fe3e34e66aca6c97b4a69f72a7f4 # v4
        with:
          tflint_version: "v0.50.0"

      - name: Init TFLint
        run: tflint --init
        working-directory: terraform/

      - name: Run TFLint
        run: tflint --recursive
        working-directory: terraform/

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@b466648d6e39e7c75324f25d83891162a721f2d6 # v1.0.3
        with:
          working_directory: terraform/
          soft_fail: false

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@5051a5cfc7e4c71d95199f81ffafbb490c7e6213 # v12
        with:
          directory: terraform/
          framework: terraform
          soft_fail: false
          skip_check: CKV_AWS_144  # Cross-region replication (not needed for dev)
```

## Caching for Faster Runs

```yaml
      - name: Cache TFLint plugins
        uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830 # v4
        with:
          path: ~/.tflint.d/plugins
          key: tflint-${{ hashFiles('terraform/.tflint.hcl') }}
```

## PR Comments

Add PR annotations for issues:

```yaml
      - name: Run tfsec with PR comments
        uses: aquasecurity/tfsec-pr-commenter-action@7a44c5dcde5dfab737363e391800629e27b6376b # v1.3.1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          working_directory: terraform/
```

## Matrix Strategy for Multiple Environments

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - name: Terraform Validate
        run: terraform -chdir=terraform/environments/${{ matrix.environment }} validate
```
