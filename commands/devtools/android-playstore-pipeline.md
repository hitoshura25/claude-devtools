---
description: Complete Android Play Store pipeline setup guide
---

# Android Play Store Pipeline

Guide for setting up complete deployment pipeline. Run each command individually for best reliability.

## ⚠️ Manual Orchestration Required

Each command below should be run separately, verifying completion before proceeding.

**Why?** Multi-step orchestration has ~40-60% reliability. Individual commands have ~95% reliability.

**Future:** MCP tool `@hitoshura25/mcp-android` will automate with 95% reliability.

## Step-by-Step Execution

### Step 1: Release Build Setup

```
/devtools:android-release-setup
```

**Verify before continuing:**
```bash
./gradlew assembleRelease
ls app/build/outputs/apk/release/app-release.apk
```

---

### Step 2: E2E Testing

```
/devtools:android-e2e-tests
```

**Verify before continuing:**
```bash
./gradlew connectedDebugAndroidTest
```

---

### Step 3: Release Validation

```
/devtools:android-release-validate
```

**Verify before continuing:**
```bash
./gradlew connectedReleaseAndroidTest
```

---

### Step 4: Play Store Setup

```
/devtools:android-playstore-setup
```

**Verify before continuing:**
- Service account created
- API enabled
- Permissions granted
- `python3 scripts/validate-playstore.py` passes

---

### Step 5: Publishing Workflows

```
/devtools:android-playstore-publish
```

**Verify before continuing:**
```bash
yamllint .github/workflows/deploy-*.yml
```

---

## Complete Pipeline Verification

After all steps complete:

```bash
# Full verification
./gradlew clean
./gradlew assembleRelease
./gradlew connectedReleaseAndroidTest
ls app/build/outputs/mapping/release/mapping.txt
```

## Next Steps After Pipeline Setup

1. Add GitHub Secrets (see `distribution/GITHUB_SECRETS.md`)
2. Setup GitHub Environment for production approval
3. Push to main → deploys to internal track
4. Tag release (v1.0.0) → deploys to production
