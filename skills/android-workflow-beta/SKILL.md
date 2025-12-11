---
name: android-workflow-beta
description: Generate GitHub Actions workflow for beta testing track deployment
category: android
version: 1.0.0
inputs:
  - package_name: Android app package name
outputs:
  - .github/workflows/deploy-beta.yml
verify: "yamllint .github/workflows/deploy-beta.yml"
---

# Android Beta Track Workflow

Generates GitHub Actions workflow for manual deployment to Play Store beta (closed testing) track.

## Prerequisites

- Service account setup complete
- Package name known

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| package_name | Yes | - | App package name |

## Process

### Step 1: Generate Beta Testing Workflow

Create `.github/workflows/deploy-beta.yml`:

```yaml
name: Deploy to Beta Testing

on:
  workflow_dispatch:
    inputs:
      track:
        description: 'Beta track'
        required: true
        type: choice
        options:
          - alpha
          - beta
        default: 'beta'
      rollout_percentage:
        description: 'Rollout percentage (for alpha: 5-100, for beta: 5-100)'
        required: false
        default: '100'

jobs:
  deploy-beta:
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

      - name: Deploy to ${{ github.event.inputs.track }}
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: ${PACKAGE_NAME}
          releaseFiles: app/build/outputs/bundle/release/app-release.aab
          track: ${{ github.event.inputs.track }}
          status: completed
          userFraction: ${{ github.event.inputs.rollout_percentage }}
          whatsNewDirectory: distribution/whatsnew

      - name: Upload AAB artifact
        uses: actions/upload-artifact@v3
        with:
          name: beta-aab-${{ github.event.inputs.track }}
          path: app/build/outputs/bundle/release/app-release.aab
          retention-days: 90

      - name: Upload mapping file
        uses: actions/upload-artifact@v3
        with:
          name: mapping-file-${{ github.event.inputs.track }}
          path: app/build/outputs/mapping/release/mapping.txt
          retention-days: 90

      - name: Summary
        run: |
          echo "✅ Deployed to ${{ github.event.inputs.track }} track"
          echo "📊 Rollout: ${{ github.event.inputs.rollout_percentage }}%"
          echo ""
          echo "🔗 View in Play Console:"
          echo "   https://play.google.com/console/developers/${PACKAGE_NAME}/tracks/${{ github.event.inputs.track }}"
```

### Step 2: Update Workflows README

Add to `.github/workflows/README.md`:

```markdown
### deploy-beta.yml
- **Trigger:** Manual only
- **Tracks:** Alpha or Beta (closed testing)
- **Approval:** None (manual trigger is the approval)
- **Rollout:** Configurable (5-100%)

## Usage - Beta Deployment

**Deploy to Beta:**
1. Go to: Actions → Deploy to Beta Testing
2. Click "Run workflow"
3. Select track: "beta"
4. Set rollout: "100" (or lower for staged beta)
5. Click "Run workflow"

**Deploy to Alpha (for smaller group):**
1. Same as above, but select track: "alpha"
2. Useful for pre-beta testing with smaller group

## Beta Testing Best Practices

1. **Use Alpha for Pre-Beta**
   - Test with small group (10-50 users)
   - Catch major issues before wider beta
   - Quick feedback loop

2. **Beta for Broader Testing**
   - Larger group (100-1000+ users)
   - Diverse devices and OS versions
   - Real-world usage patterns
   - 1-2 week minimum period

3. **Staged Beta Rollout**
   - Start at 50% for critical updates
   - Monitor for 24 hours
   - Increase to 100% if stable
   - Can halt and fix if issues found

4. **Collect Feedback**
   - Monitor crash reports in Play Console
   - Review user feedback
   - Check ANR (Application Not Responding) rate
   - Address critical issues before production
```

## Verification

**MANDATORY:** Validate workflow:

```bash
# Validate YAML syntax
yamllint .github/workflows/deploy-beta.yml

# Verify package name
grep "packageName:" .github/workflows/deploy-beta.yml
```

**Expected output:**
- No YAML syntax errors
- Package name matches your app

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| Workflow | .github/workflows/deploy-beta.yml | Beta track deployment |

## Troubleshooting

### "Track not found"
**Cause:** Beta track not created in Play Console
**Fix:** Create closed testing track in Play Console first

### "Invalid rollout percentage"
**Cause:** Value not between 5-100
**Fix:** Use valid percentage (5, 10, 20, 50, 100)

## Completion Criteria

- [ ] `.github/workflows/deploy-beta.yml` exists
- [ ] YAML syntax is valid
- [ ] Package name is correct
- [ ] Workflow supports both alpha and beta tracks
