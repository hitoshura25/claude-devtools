---
name: android-workflow-internal
description: Generate GitHub Actions workflow for internal testing track deployment
category: android
version: 1.0.0
inputs:
  - package_name: Android app package name
outputs:
  - .github/workflows/deploy-internal.yml
verify: "yamllint .github/workflows/deploy-internal.yml"
---

# Android Internal Track Workflow

Generates GitHub Actions workflow for automated deployment to Play Store internal testing track.

## Prerequisites

- Service account setup complete
- Package name known

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| package_name | Yes | - | App package name |

## Process

### Step 1: Create Workflow Directory

```bash
mkdir -p .github/workflows
```

### Step 2: Generate Internal Testing Workflow

Create `.github/workflows/deploy-internal.yml`:

```yaml
name: Deploy to Internal Testing

on:
  push:
    branches:
      - main
      - develop

jobs:
  deploy-internal:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'gradle'

      - name: Decode keystore
        run: |
          echo "${{ secrets.SIGNING_KEY_STORE_BASE64 }}" | base64 -d > release.jks
        env:
          SIGNING_KEY_STORE_BASE64: ${{ secrets.SIGNING_KEY_STORE_BASE64 }}

      - name: Build Release AAB
        run: ./gradlew bundleRelease
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/release.jks
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}

      - name: Clean up keystore
        if: always()
        run: rm -f release.jks

      - name: Deploy to Internal Testing
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: ${PACKAGE_NAME}
          releaseFiles: app/build/outputs/bundle/release/app-release.aab
          track: internal
          status: completed
          whatsNewDirectory: distribution/whatsnew

      - name: Upload AAB artifact
        uses: actions/upload-artifact@v3
        with:
          name: release-aab
          path: app/build/outputs/bundle/release/app-release.aab
          retention-days: 30

      - name: Upload mapping file
        uses: actions/upload-artifact@v3
        with:
          name: mapping-file
          path: app/build/outputs/mapping/release/mapping.txt
          retention-days: 90
```

## Verification

**MANDATORY:** Validate YAML syntax:

```bash
# Install yamllint if needed
pip install yamllint

# Validate workflow
yamllint .github/workflows/deploy-internal.yml

# Verify package name is correct
grep "packageName:" .github/workflows/deploy-internal.yml
```

**Expected output:**
- No YAML syntax errors
- Package name matches your app

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| Workflow | .github/workflows/deploy-internal.yml | Internal track deployment |

## Troubleshooting

### "YAML syntax error"
**Cause:** Invalid YAML format
**Fix:** Check indentation (use spaces, not tabs)

### "Package name incorrect"
**Cause:** Wrong package name in workflow
**Fix:** Update packageName field with correct value

## Completion Criteria

- [ ] `.github/workflows/deploy-internal.yml` exists
- [ ] YAML syntax is valid
- [ ] Package name is correct
- [ ] Workflow uses required secrets
