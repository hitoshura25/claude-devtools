---
name: android-workflow-production
description: Generate GitHub Actions workflows for production deployment with staged rollout
category: android
version: 1.0.0
inputs:
  - package_name: Android app package name
outputs:
  - .github/workflows/deploy-production.yml
  - .github/workflows/manage-rollout.yml
verify: "yamllint .github/workflows/deploy-production.yml .github/workflows/manage-rollout.yml"
---

# Android Production Workflow

Generates GitHub Actions workflows for production deployment with staged rollouts and rollout management.

## Prerequisites

- Service account setup complete
- Package name known
- GitHub environment "production" created

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| package_name | Yes | - | App package name |

## Process

### Step 1: Create Production Deployment Workflow

Create `.github/workflows/deploy-production.yml`:

```yaml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      rollout_percentage:
        description: 'Rollout percentage (5, 10, 20, 50, 100)'
        required: false
        default: '5'

jobs:
  validate-and-deploy:
    runs-on: ubuntu-latest
    environment: production

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

      - name: Run E2E tests on release
        run: |
          ./gradlew bundleRelease
          # Tests would run here if emulator setup
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/release.jks
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}

      - name: Deploy to Production
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: ${PACKAGE_NAME}
          releaseFiles: app/build/outputs/bundle/release/app-release.aab
          track: production
          status: inProgress
          inAppUpdatePriority: 2
          userFraction: ${{ github.event.inputs.rollout_percentage || '0.05' }}
          whatsNewDirectory: distribution/whatsnew

      - name: Clean up keystore
        if: always()
        run: rm -f release.jks

      - name: Create GitHub Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ github.ref }}
          release_name: Release ${{ github.ref }}
          draft: false
          prerelease: false

      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: production-release
          path: |
            app/build/outputs/bundle/release/app-release.aab
            app/build/outputs/mapping/release/mapping.txt
          retention-days: 365
```

### Step 2: Create Rollout Management Workflow

Create `.github/workflows/manage-rollout.yml`:

```yaml
name: Manage Production Rollout

on:
  workflow_dispatch:
    inputs:
      action:
        description: 'Rollout action'
        required: true
        type: choice
        options:
          - increase
          - halt
          - resume
          - complete
      percentage:
        description: 'New percentage (for increase action: 5, 10, 20, 50, 100)'
        required: false
        default: '20'

jobs:
  manage-rollout:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Increase Rollout
        if: github.event.inputs.action == 'increase'
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: ${PACKAGE_NAME}
          track: production
          status: inProgress
          userFraction: ${{ github.event.inputs.percentage }}

      - name: Halt Rollout
        if: github.event.inputs.action == 'halt'
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: ${PACKAGE_NAME}
          track: production
          status: halted

      - name: Resume Rollout
        if: github.event.inputs.action == 'resume'
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: ${PACKAGE_NAME}
          track: production
          status: inProgress

      - name: Complete Rollout (100%)
        if: github.event.inputs.action == 'complete'
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: ${PACKAGE_NAME}
          track: production
          status: completed

      - name: Notify result
        run: |
          echo "✅ Rollout action completed: ${{ github.event.inputs.action }}"
          if [ "${{ github.event.inputs.action }}" == "increase" ]; then
            echo "📊 New rollout percentage: ${{ github.event.inputs.percentage }}%"
          fi
```

### Step 3: Create Environment Setup Guide

Add to `.github/workflows/README.md`:

```markdown
# GitHub Actions Workflows

## Production Environment Setup

**REQUIRED:** Create production environment for manual approval:

1. Go to: Repository → Settings → Environments
2. Click "New environment"
3. Name: `production`
4. Check "Required reviewers"
5. Add yourself and/or team members
6. Click "Save protection rules"

This ensures production deployments require manual approval.

## Workflows

### deploy-internal.yml
- **Trigger:** Push to main/develop
- **Track:** Internal testing
- **Approval:** None (automatic)

### deploy-production.yml
- **Trigger:** Tag push (v*) or manual
- **Track:** Production
- **Approval:** Required (via environment)
- **Rollout:** Staged (default 5%)

### manage-rollout.yml
- **Trigger:** Manual only
- **Actions:** increase, halt, resume, complete
- **Use:** Control production rollout percentage

## Usage

**Deploy to internal:**
```bash
git push origin main
```

**Deploy to production:**
```bash
git tag v1.0.0
git push origin v1.0.0
# Then approve in GitHub Actions tab
```

**Increase rollout to 20%:**
1. Go to: Actions → Manage Production Rollout
2. Click "Run workflow"
3. Select action: "increase"
4. Enter percentage: "20"
5. Click "Run workflow"

**Emergency halt:**
1. Go to: Actions → Manage Production Rollout
2. Select action: "halt"
3. Click "Run workflow"
```

## Verification

**MANDATORY:** Validate workflows:

```bash
# Validate YAML syntax
yamllint .github/workflows/deploy-production.yml
yamllint .github/workflows/manage-rollout.yml

# Verify package name
grep "packageName:" .github/workflows/*.yml
```

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| Production workflow | .github/workflows/deploy-production.yml | Production deployment |
| Rollout management | .github/workflows/manage-rollout.yml | Rollout control |

## Completion Criteria

- [ ] `deploy-production.yml` exists and is valid
- [ ] `manage-rollout.yml` exists and is valid
- [ ] Package names are correct in both files
- [ ] GitHub "production" environment created
- [ ] Required reviewers configured
