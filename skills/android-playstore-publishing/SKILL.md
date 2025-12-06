---
name: android-playstore-publishing
description: Create GitHub Actions workflows for automated Play Store deployment
category: android
version: 1.0.0
---

# Android Play Store Publishing

This skill creates GitHub Actions workflows for automated deployment to Google Play Store. Supports multiple tracks, staged rollouts, and release automation.

## What This Does

1. **GitHub Actions Workflow Generation**
   - Deploy to internal testing (continuous)
   - Deploy to closed testing (alpha/beta)
   - Deploy to open testing (public beta)
   - Deploy to production (staged rollout)
   - Manual approval gates

2. **Multi-Track Support**
   - Internal track for team testing
   - Alpha/beta tracks for testers
   - Production with staged rollout
   - Configurable rollout percentages

3. **Release Automation**
   - Automatic version code increment
   - Release notes from distribution/whatsnew
   - Build, validate, and deploy in one workflow
   - Artifact preservation

4. **Deployment Triggers**
   - Push to main branch → Internal
   - Version tags → Production
   - Manual workflow dispatch
   - Pull request validation

5. **Safety Features**
   - Validation before deployment
   - Manual approval for production
   - Rollback capability
   - Deployment notifications

## Prerequisites

- Play Console setup complete (android-playstore-setup)
- SERVICE_ACCOUNT_JSON in GitHub Secrets
- Signing secrets configured
- Release build validated (android-release-validation)
- Package published to Play Console at least once (initial manual upload)

## Parameters

None required - skill will ask for configuration preferences.

## Step-by-Step Process

### Step 1: Determine Deployment Strategy

**Ask the user:**
- "Which tracks do you want to deploy to?"
  - [ ] Internal (continuous deployment)
  - [ ] Alpha/Beta (testing tracks)
  - [ ] Production (staged rollout)
- "What triggers deployment?"
  - Push to main → Internal
  - Tags (v*) → Production
  - Manual dispatch → Any track
- "Enable manual approval for production?"
  - Yes (recommended)
  - No (auto-deploy)

### Step 2: Create Internal Testing Workflow

For continuous deployment to internal track:

**File:** `.github/workflows/deploy-internal.yml`

```yaml
name: Deploy to Internal Testing

on:
  push:
    branches:
      - main
      - develop
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
          cache: 'gradle'
      
      - name: Decode signing keystore
        run: |
          echo "${{ secrets.SIGNING_KEY_STORE_BASE64 }}" | base64 --decode > release.jks
          chmod 600 release.jks
      
      - name: Build release AAB
        run: ./gradlew bundleRelease
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/release.jks
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
      
      - name: Upload to Play Store (Internal)
        uses: r0adkll/upload-google-play@v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          releaseFiles: app/build/outputs/bundle/release/app-release.aab
          track: internal
          status: completed
          whatsNewDirectory: distribution/whatsnew
      
      - name: Clean up keystore
        if: always()
        run: rm -f release.jks
      
      - name: Upload build artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: internal-release-${{ github.sha }}
          path: |
            app/build/outputs/bundle/release/app-release.aab
            app/build/outputs/mapping/release/mapping.txt
          retention-days: 30
```

**Key features:**
- Triggers on push to main/develop
- Builds release AAB
- Deploys to internal track automatically
- Preserves ProGuard mapping
- Cleans up keystore after use

### Step 3: Create Alpha/Beta Testing Workflow

For beta tester deployments:

**File:** `.github/workflows/deploy-beta.yml`

```yaml
name: Deploy to Beta Testing

on:
  workflow_dispatch:
    inputs:
      track:
        description: 'Testing track'
        required: true
        type: choice
        options:
          - alpha
          - beta
      rollout-percentage:
        description: 'Rollout percentage (1-100)'
        required: false
        default: '100'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
          cache: 'gradle'
      
      - name: Decode signing keystore
        run: |
          echo "${{ secrets.SIGNING_KEY_STORE_BASE64 }}" | base64 --decode > release.jks
      
      - name: Build and validate
        run: |
          ./gradlew clean
          ./gradlew bundleRelease
          ./gradlew assembleRelease
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/release.jks
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
      
      - name: Run validation checks
        run: |
          # Verify AAB exists
          if [ ! -f "app/build/outputs/bundle/release/app-release.aab" ]; then
            echo "❌ AAB not found"
            exit 1
          fi
          
          # Verify mapping file
          if [ ! -f "app/build/outputs/mapping/release/mapping.txt" ]; then
            echo "❌ ProGuard mapping not found"
            exit 1
          fi
          
          echo "✅ Validation passed"
      
      - name: Upload to Play Store (${{ github.event.inputs.track }})
        uses: r0adkll/upload-google-play@v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          releaseFiles: app/build/outputs/bundle/release/app-release.aab
          track: ${{ github.event.inputs.track }}
          status: completed
          inAppUpdatePriority: 2
          userFraction: ${{ github.event.inputs.rollout-percentage }}
          whatsNewDirectory: distribution/whatsnew
          mappingFile: app/build/outputs/mapping/release/mapping.txt
      
      - name: Clean up
        if: always()
        run: rm -f release.jks
      
      - name: Deployment summary
        run: |
          echo "### Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Track:** ${{ github.event.inputs.track }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Rollout:** ${{ github.event.inputs.rollout-percentage }}%" >> $GITHUB_STEP_SUMMARY
          echo "- **Build:** ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "✅ Deployment successful!" >> $GITHUB_STEP_SUMMARY
```

**Key features:**
- Manual trigger with track selection
- Configurable rollout percentage
- Validation before deployment
- ProGuard mapping upload
- Deployment summary

### Step 4: Create Production Deployment Workflow

For production releases with staging:

**File:** `.github/workflows/deploy-production.yml`

```yaml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      rollout-percentage:
        description: 'Initial rollout percentage'
        required: true
        type: choice
        options:
          - '5'
          - '10'
          - '20'
          - '50'
          - '100'
        default: '5'

jobs:
  validate:
    runs-on: macos-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
          cache: 'gradle'
      
      - name: Decode signing keystore
        run: |
          echo "${{ secrets.SIGNING_KEY_STORE_BASE64 }}" | base64 --decode > release.jks
      
      - name: Build release
        run: |
          ./gradlew clean
          ./gradlew bundleRelease
          ./gradlew assembleRelease
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/release.jks
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
      
      - name: AVD cache
        uses: actions/cache@v4
        id: avd-cache
        with:
          path: |
            ~/.android/avd/*
            ~/.android/adb*
          key: avd-production
      
      - name: Run E2E tests on release
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 30
          target: google_apis
          arch: x86_64
          script: ./gradlew connectedReleaseAndroidTest
      
      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: production-release
          path: |
            app/build/outputs/bundle/release/app-release.aab
            app/build/outputs/apk/release/app-release.apk
            app/build/outputs/mapping/release/mapping.txt
      
      - name: Clean up
        if: always()
        run: rm -f release.jks
  
  deploy:
    needs: validate
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://play.google.com/store/apps/details?id=com.example.app
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: production-release
          path: build-outputs
      
      - name: Determine rollout percentage
        id: rollout
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            echo "percentage=${{ github.event.inputs.rollout-percentage }}" >> $GITHUB_OUTPUT
          else
            echo "percentage=5" >> $GITHUB_OUTPUT
          fi
      
      - name: Upload to Play Store (Production)
        uses: r0adkll/upload-google-play@v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          releaseFiles: build-outputs/app/build/outputs/bundle/release/app-release.aab
          track: production
          status: completed
          inAppUpdatePriority: 3
          userFraction: ${{ steps.rollout.outputs.percentage }}
          whatsNewDirectory: distribution/whatsnew
          mappingFile: build-outputs/app/build/outputs/mapping/release/mapping.txt
      
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        if: startsWith(github.ref, 'refs/tags/')
        with:
          files: |
            build-outputs/app/build/outputs/apk/release/app-release.apk
            build-outputs/app/build/outputs/mapping/release/mapping.txt
          body: |
            ## Production Release
            
            Deployed to Play Store with ${{ steps.rollout.outputs.percentage }}% rollout.
            
            ### What's New
            See Play Store listing for release notes.
            
            ### Artifacts
            - AAB uploaded to Play Store
            - APK attached for reference
            - ProGuard mapping attached
      
      - name: Deployment summary
        run: |
          echo "### 🚀 Production Deployment" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Rollout:** ${{ steps.rollout.outputs.percentage }}%" >> $GITHUB_STEP_SUMMARY
          echo "- **Version:** ${{ github.ref_name }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Build:** ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "✅ Deployed successfully!" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Next steps:**" >> $GITHUB_STEP_SUMMARY
          echo "1. Monitor crash-free rate in Play Console" >> $GITHUB_STEP_SUMMARY
          echo "2. Review user feedback" >> $GITHUB_STEP_SUMMARY
          echo "3. Increase rollout if stable" >> $GITHUB_STEP_SUMMARY
```

**Key features:**
- Validates with E2E tests before deployment
- Manual approval via GitHub Environments
- Staged rollout (default 5%)
- Creates GitHub release with artifacts
- Comprehensive deployment summary

### Step 5: Create Rollout Management Workflow

For managing staged rollouts:

**File:** `.github/workflows/manage-rollout.yml`

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
        description: 'New rollout percentage (if increasing)'
        required: false
        type: choice
        options:
          - '10'
          - '20'
          - '50'
          - '100'

jobs:
  manage-rollout:
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Increase rollout
        if: github.event.inputs.action == 'increase'
        uses: r0adkll/upload-google-play@v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          track: production
          status: inProgress
          userFraction: ${{ github.event.inputs.percentage }}
      
      - name: Halt rollout
        if: github.event.inputs.action == 'halt'
        uses: r0adkll/upload-google-play@v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          track: production
          status: halted
      
      - name: Resume rollout
        if: github.event.inputs.action == 'resume'
        uses: r0adkll/upload-google-play@v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          track: production
          status: inProgress
      
      - name: Complete rollout
        if: github.event.inputs.action == 'complete'
        uses: r0adkll/upload-google-play@v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          track: production
          status: completed
          userFraction: '100'
      
      - name: Summary
        run: |
          echo "### Rollout Management" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Action:** ${{ github.event.inputs.action }}" >> $GITHUB_STEP_SUMMARY
          if [ "${{ github.event.inputs.action }}" == "increase" ]; then
            echo "- **New percentage:** ${{ github.event.inputs.percentage }}%" >> $GITHUB_STEP_SUMMARY
          fi
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "✅ Rollout updated successfully" >> $GITHUB_STEP_SUMMARY
```

**Key features:**
- Increase rollout percentage
- Halt rollout (if issues detected)
- Resume rollout
- Complete rollout to 100%

### Step 6: Setup GitHub Environment for Production

Configure production environment with approval:

**Instructions for user:**

1. Navigate to: Repository → Settings → Environments
2. Click "New environment"
3. Name: `production`
4. Configure:
   - ☑ Required reviewers: Add team members
   - ☑ Wait timer: 0 minutes (or as needed)
5. Click "Save protection rules"

**Why this matters:**
- Prevents accidental production deployments
- Requires manual approval before deployment
- Allows review of changes before going live

### Step 7: Create Deployment Documentation

**File:** `.github/workflows/README.md`

```markdown
# Deployment Workflows

## Overview

Automated deployment workflows for Play Store using GitHub Actions.

## Workflows

### 1. Internal Testing (`deploy-internal.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Manual dispatch

**Deploys to:** Internal testing track (up to 100 testers)

**Purpose:** Continuous deployment for team testing

**Usage:**
```bash
git push origin main
# Automatically deploys to internal track
```

### 2. Beta Testing (`deploy-beta.yml`)

**Triggers:**
- Manual dispatch only

**Deploys to:** Alpha or Beta track (selected at runtime)

**Purpose:** Deploy to beta testers

**Usage:**
1. Go to Actions → Deploy to Beta Testing
2. Click "Run workflow"
3. Select track (alpha or beta)
4. Set rollout percentage
5. Click "Run workflow"

### 3. Production (`deploy-production.yml`)

**Triggers:**
- Tags matching `v*` (e.g., v1.0.0)
- Manual dispatch

**Deploys to:** Production track

**Purpose:** Public releases

**Requires:** Manual approval in production environment

**Usage:**
```bash
# Tag-based deployment
git tag v1.0.0
git push origin v1.0.0
# Requires approval in GitHub Actions

# OR manual dispatch
# Go to Actions → Deploy to Production
# Click "Run workflow"
# Select rollout percentage
# Approve when prompted
```

### 4. Rollout Management (`manage-rollout.yml`)

**Triggers:**
- Manual dispatch only

**Purpose:** Manage production staged rollout

**Actions:**
- Increase: Raise rollout percentage
- Halt: Stop rollout immediately
- Resume: Continue halted rollout
- Complete: Roll out to 100%

**Usage:**
1. Go to Actions → Manage Production Rollout
2. Click "Run workflow"
3. Select action
4. If increasing, select percentage
5. Click "Run workflow"

## Deployment Flow

### Normal Release Flow

```
Development
    ↓
    Push to main
    ↓
Internal Testing (automatic)
    ↓
    Manual: Deploy to Beta
    ↓
Beta Testing (1 week)
    ↓
    Tag version (v1.0.0)
    ↓
Production (requires approval)
    ↓
5% rollout
    ↓
    Monitor 24-48 hours
    ↓
Increase to 20%
    ↓
    Monitor 24 hours
    ↓
Increase to 50%
    ↓
    Monitor 24 hours
    ↓
Complete to 100%
```

### Hotfix Flow

```
Critical Bug Detected
    ↓
Fix in hotfix branch
    ↓
    Push to main
    ↓
Internal Testing (automatic)
    ↓
    Validate fix
    ↓
    Tag hotfix (v1.0.1)
    ↓
Production (requires approval)
    ↓
20% rollout (faster than normal)
    ↓
    Monitor closely
    ↓
Complete to 100% if stable
```

## Required Secrets

All workflows require these GitHub Secrets:

- `SERVICE_ACCOUNT_JSON` - Play Console API access
- `SIGNING_KEY_STORE_BASE64` - Release keystore
- `SIGNING_KEY_ALIAS` - Keystore alias
- `SIGNING_STORE_PASSWORD` - Keystore password
- `SIGNING_KEY_PASSWORD` - Key password

See: `distribution/GITHUB_SECRETS.md`

## Monitoring Deployments

### In Play Console

1. Navigate to: Release → Production → Releases
2. Check:
   - Rollout percentage
   - Crash-free rate
   - ANR rate
   - User reviews

### In GitHub Actions

1. Navigate to: Actions tab
2. Select workflow run
3. Review:
   - Build logs
   - Test results
   - Deployment status
   - Artifacts

## Troubleshooting

**"Service account permission denied"**
→ Verify service account has "Release" permission in Play Console
→ Wait 5-10 minutes after granting permissions

**"Version code must be higher"**
→ Increment version code in build.gradle.kts
→ Each upload must have unique, higher version code

**"Release notes missing"**
→ Ensure distribution/whatsnew/en-US/whatsnew exists
→ File must be plain text, under 500 characters

**"Approval timeout"**
→ Approver must approve within timeout period
→ Re-run workflow if timeout occurs

## Best Practices

1. **Always test in internal first**
   - Never skip internal testing
   - Validate before beta/production

2. **Use staged rollouts**
   - Start with 5-10% for production
   - Increase gradually
   - Monitor crash rates between increases

3. **Tag releases properly**
   - Use semantic versioning (v1.0.0)
   - Tag only after thorough testing
   - Include release notes in tag message

4. **Monitor actively**
   - Watch crash-free rate in first 24 hours
   - Review user feedback
   - Be ready to halt rollout

5. **Keep mapping files**
   - Download from workflow artifacts
   - Store securely for each release
   - Upload to Play Console

## Emergency Procedures

### Halt Production Rollout

If critical issue detected:

1. Go to: Actions → Manage Production Rollout
2. Run workflow
3. Select action: "halt"
4. Rollout stops immediately

### Emergency Rollback

Play Store doesn't support true rollback, but you can:

1. Create hotfix with bug fix
2. Increment version code
3. Deploy hotfix to production
4. Use higher rollout percentage (20-50%)

## Support

- GitHub Actions docs: https://docs.github.com/actions
- r0adkll/upload-google-play: https://github.com/r0adkll/upload-google-play
- Play Console: https://play.google.com/console/
```

### Step 8: Validate Workflows (MANDATORY)

**CRITICAL: This step is MANDATORY and must pass before completing the skill.**

Validate workflows before deploying:

```bash
# 1. REQUIRED: Validate YAML syntax for all workflows
yamllint .github/workflows/deploy-internal.yml
yamllint .github/workflows/deploy-beta.yml
yamllint .github/workflows/deploy-production.yml
yamllint .github/workflows/manage-rollout.yml

# OR if yamllint not available, use GitHub Actions validation:
# Push to a branch and check Actions tab for syntax errors

# 2. REQUIRED: Verify workflow files exist
ls -lh .github/workflows/deploy-internal.yml
ls -lh .github/workflows/deploy-beta.yml
ls -lh .github/workflows/deploy-production.yml
ls -lh .github/workflows/manage-rollout.yml

# 3. REQUIRED: Verify workflows reference correct package name
grep "packageName: com.example.app" .github/workflows/*.yml

# 4. REQUIRED: Check GitHub Secrets are documented
[ -f "distribution/GITHUB_SECRETS.md" ] && echo "✓ Secrets documented" || echo "✗ Missing GITHUB_SECRETS.md"

# 5. REQUIRED: Verify version increment script is executable
[ -x "scripts/increment-version.sh" ] && echo "✓ Script executable" || chmod +x scripts/increment-version.sh
```

**Expected output:**
- All YAML files valid: ✓ No syntax errors
- All workflow files exist: ✓
- Package name correct: ✓ Found in all workflows
- Secrets documented: ✓
- Scripts executable: ✓

**If ANY fail:**
1. DO NOT complete skill
2. Fix YAML syntax errors
3. Update package names
4. Make scripts executable
5. Re-run validation
6. Only complete when ALL pass

**Common Failures:**
- "YAML syntax error" → Fix indentation, quotes, structure
- "Package name mismatch" → Update {PACKAGE_NAME} placeholder
- "Script not executable" → Run `chmod +x scripts/increment-version.sh`

### Step 9: Version Code Management

Create script for version code increment:

**File:** `scripts/increment-version.sh`

```bash
#!/bin/bash
# Increment Android version code automatically

BUILD_GRADLE="app/build.gradle.kts"

if [ ! -f "$BUILD_GRADLE" ]; then
    echo "❌ build.gradle.kts not found"
    exit 1
fi

# Extract current version code
CURRENT_VERSION=$(grep "versionCode = " "$BUILD_GRADLE" | sed 's/.*versionCode = \([0-9]*\).*/\1/')

if [ -z "$CURRENT_VERSION" ]; then
    echo "❌ Could not find version code"
    exit 1
fi

NEW_VERSION=$((CURRENT_VERSION + 1))

echo "Incrementing version code: $CURRENT_VERSION → $NEW_VERSION"

# Update build.gradle.kts
sed -i.bak "s/versionCode = $CURRENT_VERSION/versionCode = $NEW_VERSION/" "$BUILD_GRADLE"
rm "${BUILD_GRADLE}.bak"

echo "✅ Version code updated to $NEW_VERSION"
```

### Step 10: Generate Summary

```
✅ Play Store Publishing Workflows Created!

📦 Workflows Generated:
  ✓ deploy-internal.yml - Continuous deployment to internal track
  ✓ deploy-beta.yml - Manual deployment to alpha/beta
  ✓ deploy-production.yml - Production with staged rollout
  ✓ manage-rollout.yml - Rollout management

⚙️  Configuration:
  ✓ Triggers: Push, tags, manual dispatch
  ✓ Validation: E2E tests before production
  ✓ Approval: Manual approval for production
  ✓ Rollout: Staged rollout (5% → 100%)
  ✓ Artifacts: AAB, APK, ProGuard mapping preserved

📝 Documentation Created:
  ✓ .github/workflows/README.md - Usage guide
  ✓ scripts/increment-version.sh - Version management

🔐 Security:
  ✓ Keystore cleanup after use
  ✓ Secrets never logged
  ✓ Environment protection for production

📋 Next Steps:

  1. Setup GitHub Environment:
     - Repository → Settings → Environments
     - Create "production" environment
     - Add required reviewers
     - Save protection rules
  
  2. Verify GitHub Secrets:
     - SERVICE_ACCOUNT_JSON ✓
     - Signing secrets ✓
  
  3. First Deployment:
     - Update release notes: distribution/whatsnew/en-US/whatsnew
     - Push to main → Deploys to internal automatically
     - Test on device
     - Deploy to beta manually
     - Tag for production (v1.0.0)
  
  4. Monitor Deployment:
     - GitHub Actions tab for workflow status
     - Play Console for rollout metrics
     - User reviews and crash reports

⚠️  Important Reminders:
  - First upload MUST be manual through Play Console
  - Version code must increment with each upload
  - ProGuard mapping files saved automatically
  - Production requires manual approval
  - Use staged rollouts (start with 5%)
  - Monitor crash-free rate actively

🚀 Ready to Deploy!

  Test deployment to internal:
    git add .
    git commit -m "Add Play Store workflows"
    git push origin main
    # Automatically deploys to internal track
  
  Production deployment:
    git tag v1.0.0
    git push origin v1.0.0
    # Requires approval, then deploys with staged rollout
```

## Error Handling

### Build Failures

**Gradle build fails:**
- Check signing configuration
- Verify secrets are correct
- Ensure dependencies are cached

**ProGuard errors:**
- Review proguard-rules.pro
- Add keep rules for failing classes
- Test locally first

### Deployment Failures

**"Package not found":**
- App must be created in Play Console
- First upload must be manual
- Verify package name matches exactly

**"Version code already exists":**
- Increment version code
- Each upload needs unique version code
- Check Play Console for current version

**"Insufficient permissions":**
- Verify service account has "Release" permission
- Check service account is linked in Play Console
- Wait 5-10 minutes for permissions to propagate

### Workflow Failures

**"Secret not found":**
- Verify secret names match exactly (case-sensitive)
- Check secrets are set in repository settings
- Ensure secrets have values (not empty)

**"Approval timeout":**
- Approver must approve within timeout
- Check notifications are enabled
- Re-run workflow after timeout

**"Artifact not found":**
- Verify build step completed successfully
- Check artifact upload/download names match
- Ensure artifacts haven't expired (30 day default)

## Security Best Practices

1. **Environment Protection**
   - Require approval for production
   - Limit who can approve
   - Use wait timers if needed

2. **Secret Management**
   - Rotate service account keys annually
   - Never log secret values
   - Use environment-specific secrets

3. **Keystore Handling**
   - Decode just before use
   - Delete immediately after
   - Never commit decoded keystore

4. **Artifact Security**
   - Store mapping files securely
   - Set appropriate retention
   - Encrypt sensitive artifacts

## Integration with Other Skills

This skill integrates with:
- `android-release-build-setup` - Uses signing configuration
- `android-e2e-testing-setup` - Runs tests before production
- `android-release-validation` - Validates builds before upload
- `android-playstore-setup` - Uses service account and release notes
- `android-playstore-pipeline` - Orchestrates complete workflow

## Troubleshooting

### "Upload failed: The app bundle must be signed"
- Verify signing secrets are correct
- Check keystore decoding step
- Ensure SIGNING_KEY_STORE_PATH is correct

### "Cannot promote to track with higher version code"
- Increment version code before deploying
- Check version codes in each track
- Use continuous versioning strategy

### "Release notes exceed character limit"
- Check distribution/whatsnew files
- Ensure each file < 500 characters
- Remove extra whitespace

## Files Created/Modified

**Created:**
- `.github/workflows/deploy-internal.yml`
- `.github/workflows/deploy-beta.yml`
- `.github/workflows/deploy-production.yml`
- `.github/workflows/manage-rollout.yml`
- `.github/workflows/README.md`
- `scripts/increment-version.sh`

**Modified:**
- None (workflows are standalone)

## Completion Criteria (ALL MUST PASS)

Do NOT mark this skill as complete unless ALL of the following are verified:

✅ **Workflow files created**
  - [ ] .github/workflows/deploy-internal.yml exists
  - [ ] .github/workflows/deploy-beta.yml exists
  - [ ] .github/workflows/deploy-production.yml exists
  - [ ] .github/workflows/manage-rollout.yml exists

✅ **MANDATORY: Workflow validation**
  - [ ] All YAML files have valid syntax (no parse errors)
  - [ ] Package name updated in all workflows (no {PACKAGE_NAME} placeholders)
  - [ ] All workflows reference correct secrets names
  - [ ] Workflows have correct triggers configured

✅ **Scripts created**
  - [ ] scripts/increment-version.sh exists and is executable
  - [ ] Script can parse version code from build.gradle.kts

✅ **Documentation created**
  - [ ] .github/workflows/README.md exists
  - [ ] README documents all 4 workflows
  - [ ] README includes usage examples
  - [ ] README includes troubleshooting section

✅ **GitHub Secrets documented**
  - [ ] distribution/GITHUB_SECRETS.md lists all required secrets
  - [ ] Instructions for SERVICE_ACCOUNT_JSON included
  - [ ] Instructions for signing secrets included

**If ANY checkbox is unchecked, the skill is NOT complete.**

## Expected Outcomes

After running this skill:

✅ **Automated deployment** to all tracks configured
✅ **Validation gates** ensure quality before deployment
✅ **Manual approval** required for production
✅ **Staged rollouts** minimize risk
✅ **Artifact preservation** for debugging
✅ **Ready for CI/CD** complete automation

## Next Skills (Dependencies)

This skill DEPENDS on:
- `android-release-build-setup` - Must complete first (uses signing config)
- `android-e2e-testing-setup` - Must complete first (workflows run tests)
- `android-release-validation` - Must complete first (validates before deploy)
- `android-playstore-setup` - Must complete first (uses service account)

This skill is a PREREQUISITE for:
- `android-playstore-pipeline` - Part of complete workflow

Do NOT run this skill until ALL four dependencies' completion criteria are met.

## References

- [GitHub Actions](https://docs.github.com/en/actions)
- [upload-google-play Action](https://github.com/r0adkll/upload-google-play)
- [Play Console Publishing](https://support.google.com/googleplay/android-developer/answer/9859348)
- [Staged Rollouts](https://support.google.com/googleplay/android-developer/answer/6346149)
