# Skills Bug Fixes Implementation Spec v4

## Overview

This spec addresses feedback from GitHub PR review and additional user requirements.

---

## Part 1: GitHub PR Feedback Fixes

### 1.1 Task Matching Pattern Too Broad

**File:** `skills/android-signing-config/SKILL.md`

**Problem:** `tasks.matching { it.name.contains("Release") }` matches unintended tasks.

**Fix:**
```kotlin
// Before (too broad)
tasks.matching { it.name.contains("Release") }

// After (specific to build tasks)
tasks.matching { 
    it.name.matches(Regex(".*[aA]ssemble.*Release.*|.*[bB]undle.*Release.*"))
}
```

---

### 1.2 Test Libraries in Release ProGuard Rules

**File:** `skills/android-proguard-setup/SKILL.md`

**Problem:** Keeping test libraries in release builds increases APK size.

**Fix:** Remove these rules entirely from `proguard-rules.pro`:

```proguard
# REMOVE THESE - test libraries should NOT be in release builds
# -keep class androidx.test.** { *; }
# -keep class com.google.common.truth.** { *; }
# -keep class org.junit.** { *; }
```

Test libraries are `androidTestImplementation` only - they're never included in release APKs.

---

### 1.3 Rollout Workflows Missing `releaseFiles`

**Files:** `skills/android-workflow-production/SKILL.md` (manage-rollout.yml template)

**Problem:** Increase/Halt/Resume/Complete rollout steps may need `releaseFiles`.

**Research Result:** Based on the r0adkll/upload-google-play action documentation:
- For **new uploads**: `releaseFiles` is required
- For **rollout management** (increase, halt, resume, complete): The action manages existing releases, so `releaseFiles` may not be needed

**However**, the action's behavior for rollout-only operations is unclear. The safer approach is to use the **promote-play-release** action for track promotions:

```yaml
# For promoting between tracks (e.g., internal → beta → production)
- name: Promote to Beta
  uses: kevin-david/promote-play-release@v1.0.1  # Pin to specific version
  with:
    service-account-json-raw: ${{ secrets.SERVICE_ACCOUNT_JSON }}
    package-name: ${{ env.PACKAGE_NAME }}
    from-track: internal
    to-track: beta
    user-fraction: 0.5
```

**Alternative:** For rollout management of existing releases, consider using the Google Play Developer API directly via a custom script.

---

### 1.4 Deprecated `actions/create-release@v1`

**File:** `skills/android-workflow-production/SKILL.md` (deploy-production.yml template)

**Problem:** `actions/create-release@v1` is deprecated (unmaintained since 2021).

**Fix:** Use GitHub CLI instead:

```yaml
# Before (deprecated)
- name: Create GitHub Release
  uses: actions/create-release@v1
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    tag_name: ${{ github.ref }}
    release_name: Release ${{ github.ref }}
    draft: false
    prerelease: false

# After (recommended)
- name: Create GitHub Release
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    gh release create "${{ github.ref_name }}" \
      --title "Release ${{ github.ref_name }}" \
      --notes "Release notes for ${{ github.ref_name }}" \
      --latest \
      app/build/outputs/bundle/release/app-release.aab
```

---

### 1.5 Permission Error Message Unclear

**File:** `skills/android-playstore-api-validation/SKILL.md` (validate-playstore.py)

**Problem:** Line 89 says "Release permission" but should be more specific.

**Fix:**
```python
# Before
print("Error: Service account needs 'Release' permission")

# After  
print("Error: Service account needs 'Release apps to production tracks' permission.")
print("In Play Console: Setup > API access > Grant access > select your service account")
print("Required: 'Release to production, exclude devices, and use Play App Signing'")
```

---

### 1.6 `userFraction` with `status: completed`

**File:** `skills/android-workflow-beta/SKILL.md` (deploy-beta.yml template)

**Problem:** When `status: completed`, `userFraction` is ignored and shouldn't be set.

**Fix:**
```yaml
# For staged rollout (partial users)
- name: Deploy to Beta (Staged)
  uses: r0adkll/upload-google-play@v1.1.3
  with:
    # ...
    track: beta
    status: inProgress  # Use inProgress for staged rollouts
    userFraction: 0.5   # Only valid with inProgress

# For full rollout (all users)
- name: Deploy to Beta (Full)
  uses: r0adkll/upload-google-play@v1.1.3
  with:
    # ...
    track: beta
    status: completed   # Full rollout to all users
    # userFraction: DO NOT SET when status is completed
```

---

### 1.7 Pin GitHub Actions to Commit SHA

**Files:** All workflow templates

**Problem:** Using mutable tags like `@v1` is a supply chain risk.

**Fix:** Pin to specific commit SHAs:

```yaml
# Before (mutable tag - risky)
uses: r0adkll/upload-google-play@v1

# After (pinned to commit SHA - secure)
# v1.1.3 = 935ef9c68bb393a8e6116b1575626a7f5be3a7fb
uses: r0adkll/upload-google-play@935ef9c68bb393a8e6116b1575626a7f5be3a7fb

# Add comment for maintainability
# uses: r0adkll/upload-google-play@v1.1.3
```

**Full list of actions to pin:**

| Action | Current | Pin To (SHA) |
|--------|---------|--------------|
| `r0adkll/upload-google-play@v1` | v1.1.3 | `935ef9c68bb393a8e6116b1575626a7f5be3a7fb` |
| `actions/checkout@v4` | v4.2.2 | `11bd71901bbe5b1630ceea73d27597364c9af683` |
| `actions/setup-java@v4` | v4.7.0 | `c5195efecf7bdfc987ee8bae7a71cb8b11521c00` |
| `actions/upload-artifact@v4` | v4.6.0 | `ea165f8d65b6e75b540449e92b4886f43607fa02` |
| `actions/download-artifact@v4` | v4.1.8 | `fa0a91b85d4f404e444e00e005971372dc801d16` |
| `actions/cache@v4` | v4.2.0 | `1bd1e32a3bdc45362d1e726936510720a7c30a57` |

---

### 1.8 `upload-artifact@v3` Deprecated

**Files:** All workflow templates

**Problem:** `actions/upload-artifact@v3` is deprecated.

**Fix:** Update to v4:

```yaml
# Before
uses: actions/upload-artifact@v3

# After (with SHA pinning)
uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.0
```

---

## Part 2: User Feedback - Security & Configuration

### 2.1 Keystore Password Security

**Question:** Is the password generation insecure given the agent knows it?

**Analysis:**
- The agent generates and sees the password during execution
- The password is stored in `KEYSTORE_INFO.txt` and `/tmp/*.txt` temporarily
- In Claude Code context, the agent has access to the conversation

**Options to improve security:**

#### Option A: User-Provided Password (Most Secure)

```markdown
### Password Generation

**Choose one option:**

**Option 1 (Recommended): User provides password**
> "Please enter a password for the production keystore (min 12 characters):"

The agent will NOT see or store your password. You'll enter it directly when running keytool.

**Option 2: Generated password**
If you prefer a generated password, the agent will create one. Note that the agent 
will have access to this password during the session.
```

#### Option B: External Password Manager Integration

```bash
# Generate password and immediately store in system keychain (macOS)
PROD_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
security add-generic-password -a "$USER" -s "android-release-keystore-prod" -w "$PROD_PASSWORD"
unset PROD_PASSWORD

# Retrieve later without exposing
PROD_PASSWORD=$(security find-generic-password -a "$USER" -s "android-release-keystore-prod" -w)
```

#### Option C: Environment Variable (Current Approach)

The current approach is acceptable for most use cases because:
1. Production keystore should only be used in CI/CD (not locally)
2. The password for local dev keystore is less sensitive
3. Passwords are stored in GitHub Secrets, not in code

**Recommendation:** Add Option A as the default, with Option B for advanced users.

---

### 2.2 Environment Variable Prefix for Signing

**Problem:** Signing env vars like `SIGNING_KEY_STORE_PATH` may clash with other projects.

**Solution:** Auto-detect prefix from project name:

```markdown
### Signing Environment Variable Prefix

**Step 1: Detect project name**
```bash
# From settings.gradle.kts
PROJECT_NAME=$(grep "rootProject.name" settings.gradle.kts | sed 's/.*"\(.*\)".*/\1/' | tr '[:lower:]' '[:upper:]' | tr '-' '_')
echo "Detected project: $PROJECT_NAME"
```

**Step 2: Ask user for prefix preference**

> "Choose environment variable prefix for signing configuration:
> 1. **{PROJECT_NAME}** (detected from project) - e.g., `HEALTH_SYNC_APP_SIGNING_KEY_STORE_PATH`
> 2. **APP** (generic) - e.g., `APP_SIGNING_KEY_STORE_PATH`
> 3. **Custom** - Enter your own prefix
> 
> Select option (1/2/3):"

**Step 3: Use selected prefix**
```kotlin
// In build.gradle.kts
val prefix = "{SELECTED_PREFIX}"

signingConfigs {
    create("release") {
        storeFile = file(System.getenv("${prefix}_SIGNING_KEY_STORE_PATH") ?: "")
        storePassword = System.getenv("${prefix}_SIGNING_STORE_PASSWORD") ?: ""
        keyAlias = System.getenv("${prefix}_SIGNING_KEY_ALIAS") ?: ""
        keyPassword = System.getenv("${prefix}_SIGNING_KEY_PASSWORD") ?: ""
    }
}
```

**GitHub Secrets to create:**
- `{PREFIX}_SIGNING_KEY_STORE_BASE64`
- `{PREFIX}_SIGNING_KEY_ALIAS`
- `{PREFIX}_SIGNING_STORE_PASSWORD`
- `{PREFIX}_SIGNING_KEY_PASSWORD`
```

---

### 2.3 ProGuard Rule Generation from Project Analysis

**Question:** Can we scan the project to generate accurate ProGuard rules?

**Analysis:**
- Automatic ProGuard rule generation is complex and error-prone
- Libraries often provide their own consumer ProGuard rules
- The iterative approach (run tests, fix failures, repeat) is more reliable
- The current `android-proguard-setup` skill provides common rules

**Recommendation:** 
1. Keep the iterative validation approach (it works well)
2. Enhance `android-proguard-setup` skill with library-specific rules:

```markdown
### Library-Specific ProGuard Rules

**Check your dependencies and add relevant rules:**

#### Retrofit/OkHttp
```proguard
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
```

#### Gson
```proguard
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
```

#### Kotlin Serialization
```proguard
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
```

#### Health Connect
```proguard
-keep class androidx.health.connect.client.** { *; }
-keep class androidx.health.platform.client.** { *; }
```
```

---

### 2.4 Python Virtual Environment for validate-playstore.py

**File:** `skills/android-playstore-api-validation/SKILL.md`

**Fix:**
```markdown
### Run Validation Script

**Step 1: Create virtual environment**
```bash
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

**Step 2: Install dependencies**
```bash
pip install google-api-python-client google-auth
```

**Step 3: Run validation**
```bash
python validate-playstore.py
```

**Step 4: Deactivate when done**
```bash
deactivate
```
```

---

## Part 3: User Feedback - Play Store Publishing

### 3.1 Combine android-playstore-setup with android-playstore-publish?

**Analysis:**
- `android-playstore-setup`: One-time setup (service account, release notes structure)
- `android-playstore-publish`: Actual publishing workflows

**Recommendation:** Keep them separate because:
1. Setup is run once per project
2. Publishing workflows are templates added/modified over time
3. Separation follows single-responsibility principle

However, the setup skill should clearly reference the publish skill at the end:

```markdown
## Next Steps

Setup complete! Now run:
```
/devtools:android-playstore-publish
```
to create the GitHub Actions workflows for publishing to Play Store.
```

---

### 3.2 Track Differences: Alpha vs Beta vs Internal

**Add to documentation:**

```markdown
### Play Store Release Tracks

| Track | Audience | Use Case |
|-------|----------|----------|
| **Internal** | Up to 100 internal testers | Quick testing, no review needed, instant availability |
| **Closed (Alpha)** | Invited testers only | Early testing with specific user groups |
| **Open (Beta)** | Anyone can join | Public beta testing before production |
| **Production** | All users | Full public release |

**Recommended workflow:**
1. **Internal** → Developers and QA team for every PR/commit
2. **Beta** → Wider testing before production releases
3. **Production** → Full public release (manual approval recommended)

**Note:** "Alpha" and "Beta" are now called "Closed testing" and "Open testing" in Play Console, 
but the API track names remain `alpha` and `beta`.
```

---

### 3.3 Workflow Triggers

**Problem:** All workflows shouldn't auto-trigger on push.

**Solution:**

```yaml
# deploy-internal.yml - Auto-trigger on main branch
on:
  push:
    branches: [main]
  workflow_dispatch:  # Manual trigger

# deploy-beta.yml - Manual only (requires approval)
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy'
        required: true

# deploy-production.yml - Manual only (requires approval)
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy'
        required: true
      confirm_production:
        description: 'Type "DEPLOY" to confirm production release'
        required: true
```

---

### 3.4 Run Tests Before Deployment

**Add test job before deployment:**

```yaml
jobs:
  # Run tests first
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
      
      - name: Set up JDK
        uses: actions/setup-java@c5195efecf7bdfc987ee8bae7a71cb8b11521c00  # v4.7.0
        with:
          java-version: '17'
          distribution: 'temurin'
      
      - name: Setup Gradle cache
        uses: actions/cache@1bd1e32a3bdc45362d1e726936510720a7c30a57  # v4.2.0
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
            .gradle/configuration-cache
          key: gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
          restore-keys: |
            gradle-${{ runner.os }}-
      
      - name: Run unit tests
        run: ./gradlew test
      
      - name: Upload test reports
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.0
        with:
          name: test-reports
          path: app/build/reports/tests/
          retention-days: 7

  # Deploy only if tests pass
  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      # ... deployment steps
```

---

### 3.5 Gradle Caching

**Add to workflow templates:**

```yaml
- name: Setup Gradle cache
  uses: actions/cache@1bd1e32a3bdc45362d1e726936510720a7c30a57  # v4.2.0
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
      .gradle/configuration-cache
    key: gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
    restore-keys: |
      gradle-${{ runner.os }}-

- name: Setup Gradle
  uses: gradle/actions/setup-gradle@v4
  with:
    cache-disabled: true  # Using manual cache above
```

---

### 3.6 Manual Upload Requirement

**Add to documentation:**

```markdown
### First-Time Upload Requirement

⚠️ **Important:** Before GitHub Actions can upload to Play Store, you must:

1. **Manually upload your first AAB** through Play Console
2. Complete the **store listing** (title, description, screenshots)
3. Set up **content rating**
4. Complete **app content** declarations
5. Create at least one **release** in any track

**Why?** The Play Store API requires the app to exist before automation can upload new versions.

**After manual setup:**
- GitHub Actions can upload new versions automatically
- All tracks become available for automated deployment
```

---

### 3.7 Debug Symbols Upload

**Add to workflow templates:**

```yaml
- name: Upload to Play Store
  uses: r0adkll/upload-google-play@935ef9c68bb393a8e6116b1575626a7f5be3a7fb  # v1.1.3
  with:
    serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
    packageName: ${{ env.PACKAGE_NAME }}
    releaseFiles: app/build/outputs/bundle/release/app-release.aab
    track: internal
    status: completed
    whatsNewDirectory: distribution/whatsnew
    mappingFile: app/build/outputs/mapping/release/mapping.txt
    # Add debug symbols for better crash reports
    debugSymbols: app/build/intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib
```

**Note:** Debug symbols are only needed if your app includes native code (NDK). If you get "path not found", your app doesn't have native libraries and you can omit this parameter.

---

### 3.8 Upload Action "Unknown Error" - Fastlane Alternative

**Problem:** `r0adkll/upload-google-play` gives "Unknown error" with no debug info.

**Options:**

#### Option A: Add Debug Logging

```yaml
- name: Upload to Play Store
  uses: r0adkll/upload-google-play@935ef9c68bb393a8e6116b1575626a7f5be3a7fb
  with:
    # ... other params
  env:
    # Enable debug logging
    ACTIONS_STEP_DEBUG: true
```

#### Option B: Use Fastlane Instead

```yaml
- name: Install Fastlane
  run: |
    gem install fastlane
    
- name: Deploy with Fastlane
  env:
    SUPPLY_JSON_KEY_DATA: ${{ secrets.SERVICE_ACCOUNT_JSON }}
  run: |
    fastlane supply \
      --aab app/build/outputs/bundle/release/app-release.aab \
      --track internal \
      --package_name ${{ env.PACKAGE_NAME }} \
      --release_status completed \
      --skip_upload_apk true \
      --skip_upload_metadata true \
      --skip_upload_images true \
      --skip_upload_screenshots true
```

#### Option C: Custom Python Script

Create `scripts/upload-to-play-store.py`:

```python
#!/usr/bin/env python3
"""
Upload AAB to Google Play Store with detailed error logging.
"""

import os
import sys
import json
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

def main():
    # Configuration
    package_name = os.environ.get('PACKAGE_NAME')
    aab_path = os.environ.get('AAB_PATH', 'app/build/outputs/bundle/release/app-release.aab')
    track = os.environ.get('TRACK', 'internal')
    service_account_json = os.environ.get('SERVICE_ACCOUNT_JSON')
    
    if not all([package_name, service_account_json]):
        print("❌ Missing required environment variables")
        sys.exit(1)
    
    try:
        # Parse service account JSON
        credentials_info = json.loads(service_account_json)
        credentials = service_account.Credentials.from_service_account_info(
            credentials_info,
            scopes=['https://www.googleapis.com/auth/androidpublisher']
        )
        
        # Build API client
        print("🔐 Authenticating with Google Play API...")
        service = build('androidpublisher', 'v3', credentials=credentials)
        
        # Create edit
        print(f"📝 Creating edit for {package_name}...")
        edit = service.edits().insert(packageName=package_name).execute()
        edit_id = edit['id']
        print(f"  Edit ID: {edit_id}")
        
        # Upload AAB
        print(f"📤 Uploading {aab_path}...")
        media = MediaFileUpload(aab_path, mimetype='application/octet-stream')
        bundle = service.edits().bundles().upload(
            packageName=package_name,
            editId=edit_id,
            media_body=media
        ).execute()
        version_code = bundle['versionCode']
        print(f"  Version code: {version_code}")
        
        # Assign to track
        print(f"🚀 Assigning to {track} track...")
        service.edits().tracks().update(
            packageName=package_name,
            editId=edit_id,
            track=track,
            body={
                'track': track,
                'releases': [{
                    'versionCodes': [version_code],
                    'status': 'completed'
                }]
            }
        ).execute()
        
        # Commit edit
        print("✅ Committing edit...")
        service.edits().commit(packageName=package_name, editId=edit_id).execute()
        
        print(f"🎉 Successfully uploaded to {track} track!")
        
    except Exception as e:
        print(f"❌ Error: {type(e).__name__}: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

**Recommendation:** Start with Option A (debug logging). If issues persist, Option C gives full control and visibility.

---

## Part 4: New Skills/Commands Needed

Based on the reference workflow from `mpo-api-authn-server`, consider creating:

### 4.1 `android-ci-tests` skill

For running tests with emulator in CI:

```markdown
# Android CI Tests Setup

Sets up GitHub Actions workflow for running Android instrumented tests with emulator.

## Features
- AVD caching for faster builds
- KVM acceleration setup
- Gradle caching
- Test report artifacts
```

### 4.2 `android-gradle-cache` skill

For optimizing Gradle builds:

```markdown
# Android Gradle Cache Setup

Configures optimal Gradle caching for Android projects in CI.

## Features
- Configuration cache
- Build cache
- Dependency cache
- Cross-workflow cache sharing
```

---

## Part 5: Play Store Setup & Privacy Policy

### 5.1 Migrate from r0adkll to Gradle Play Publisher

**Problem:** The `r0adkll/upload-google-play` action is in maintenance mode and has poor error visibility.

**Solution:** Migrate to Gradle Play Publisher (GPP) which is actively maintained (v3.13.0, Dec 2025).

#### Comparison

| Feature | r0adkll/upload-google-play | Gradle Play Publisher |
|---------|---------------------------|----------------------|
| Maintenance | Maintenance mode | Active (Dec 2025) |
| Error Messages | Poor ("Unknown error") | Excellent (Gradle output) |
| Integration | GitHub Action | Native Gradle |
| Auth | Action parameter | Environment variable |
| Version Handling | Manual | Built-in conflict resolution |

#### Migration Steps

**1. Add GPP to `app/build.gradle.kts`:**

```kotlin
plugins {
    id("com.android.application")
    id("com.github.triplet.play") version "3.13.0"
}

play {
    // Auth via ANDROID_PUBLISHER_CREDENTIALS env var in CI
    track.set("internal")
    defaultToAppBundles.set(true)
    // Release notes location: src/main/play/release-notes/en-US/default.txt
}
```

**2. Update workflow:**

```yaml
# Before (r0adkll)
- uses: r0adkll/upload-google-play@v1
  with:
    serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON_PLAINTEXT }}
    packageName: io.github.hitoshura25.healthsyncapp
    releaseFiles: app/build/outputs/bundle/release/app-release.aab
    track: internal

# After (GPP)
- name: Publish to Play Store
  env:
    ANDROID_PUBLISHER_CREDENTIALS: ${{ secrets.SERVICE_ACCOUNT_JSON_PLAINTEXT }}
  run: ./gradlew publishBundle --track internal
```

**3. Create release notes directory:**

```
src/main/play/
├── release-notes/
│   └── en-US/
│       └── default.txt
└── listings/
    └── en-US/
        ├── title.txt
        ├── short-description.txt
        └── full-description.txt
```

---

### 5.2 Play App Signing Workflow

**Key Discovery:** Play App Signing is **automatic** for apps created after August 2021. No "enable" button needed.

#### Two Keys Explained

| Key Type | Purpose | Who Holds | Can Reset? |
|----------|---------|-----------|------------|
| **App Signing Key** | Signs APKs distributed to users | Google | No (permanent) |
| **Upload Key** | Authenticates developer uploads | Developer | Yes (via Play Console) |

#### Correct First Upload Workflow

```
Step 1: Generate Production Keystore
    └── /devtools:android-keystore-generation
    └── Creates: keystores/production-release.jks

Step 2: Enable Play App Signing (Automatic)
    └── Happens during first release creation
    └── Choose: "Let Google generate app signing key" (recommended)

Step 3: First Upload with Production Keystore
    └── Build AAB locally: ./gradlew bundleRelease
    └── Upload via Play Console (NOT CI yet)
    └── This registers production keystore as upload key

Step 4: Configure CI with Same Keystore
    └── Add production keystore to GitHub Secrets
    └── CI uploads will now match registered upload key

Step 5: Test CI Upload
    └── Should succeed (same key as first upload)
```

**CRITICAL:** First upload keystore = CI keystore. Must be the same.

#### Key Mismatch Error Fix

If you see:
```
Error: The Android App Bundle was signed with the wrong key.
Found: SHA1: 36:02:D6:...  ← Local dev keystore
Expected: SHA1: 00:33:A2:...  ← Production keystore
```

**Fix:** Request upload key reset in Play Console → Setup → App signing → Request upload key reset

---

### 5.3 Play Console Setup Scanner

**New Skill:** `/devtools:android-playstore-scan`

**Purpose:** Analysis only - scans the project and generates a document with pre-filled answers for Play Console setup. Does NOT modify any files.

**Relationship to `android-playstore-setup`:**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Play Store Publishing Pipeline                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. /devtools:android-playstore-scan          [ANALYSIS - READ ONLY]│
│     └── Scans project (manifest, build.gradle, dependencies)        │
│     └── Generates PLAY_CONSOLE_SETUP.md with pre-filled answers     │
│     └── Identifies gaps (no privacy policy, missing config)         │
│     └── OUTPUT: Checklist + recommendations                         │
│                          │                                          │
│                          ▼                                          │
│  2. User reviews PLAY_CONSOLE_SETUP.md                              │
│     └── Confirms/adjusts detected values                            │
│     └── Provides missing info (contact email, company name, etc.)   │
│                          │                                          │
│                          ▼                                          │
│  3. /devtools:android-playstore-setup         [EXECUTION - WRITES]  │
│     └── Reads PLAY_CONSOLE_SETUP.md as input (or prompts if missing)│
│     └── Executes setup tasks:                                       │
│         ├── /devtools:privacy-policy-generate                       │
│         ├── Configure GPP plugin in build.gradle                    │
│         ├── Create src/main/play/ directory structure               │
│         ├── Setup GitHub workflows                                  │
│         └── /devtools:android-keystore-generation (if needed)       │
│     └── OUTPUT: Ready-to-publish project                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Why Two Skills:**
1. **Validation before execution** - User can review before changes are made
2. **Composable** - Each skill can be used independently
3. **Reliability** - Single-purpose tools are more reliable than multi-mode

#### What Agent Can Detect

| Play Console Task | Can Detect | What to Scan |
|-------------------|------------|--------------|
| Privacy policy | ⚠️ Partial | Check if URL exists, generate template |
| App access | ✅ Yes | Login screens, auth libraries |
| Ads | ✅ Yes | AdMob, Facebook Ads SDK |
| Content rating | ⚠️ Partial | Violence, gambling, UGC patterns |
| Target audience | ⚠️ Partial | COPPA compliance indicators |
| Data safety | ✅ Yes | Permissions, network calls, analytics |
| Health | ✅ Yes | Health Connect API usage |
| Financial features | ✅ Yes | Payment SDKs |
| Store listing | ✅ Yes | App name, generate description drafts |

#### Output: `PLAY_CONSOLE_SETUP.md`

```markdown
# Play Console Setup Guide for: Health Sync App

## 1. Privacy Policy
**Status:** ⚠️ Action Required
**Detected:** No privacy policy URL found
**Action:** Run `/devtools:privacy-policy-generate`
**Suggested URL:** https://hitoshura25.github.io/health-sync-app/privacy-policy

## 2. App Access
**Detected:** Login not required
**Answer:** "All functionality available without special access"

## 3. Ads Declaration
**Detected SDKs:** None
**Answer:** "No, my app does not contain ads"

## 4. Content Rating
**Estimated Rating:** Everyone (E)
- Violence: No
- Sexual content: No  
- Gambling: No

## 5. Data Safety Form
**Data Collected:**
- Health info: Yes (Health Connect API detected)
- Device ID: No
- Location: No

**Security:**
- Data encrypted in transit: Yes (HTTPS detected)
- Data encrypted at rest: [User to confirm]

## 6. Health App Declaration
**Detected:** Health Connect API usage
**Health Data Types:**
- Steps (read/write)
- Heart rate (read)
- Sleep (read)

**Action Required:** Complete Health Apps declaration form in Play Console

## 7. Store Listing (Draft)
**Title:** Health Sync App
**Short Description:** Sync your health data across devices with Health Connect.

## 8. First Upload Checklist
- [ ] Generate production keystore
- [ ] Build release AAB: ./gradlew bundleRelease
- [ ] Upload to Play Console → Internal testing
- [ ] Note: This registers your upload key certificate
```

---

### 5.4 Privacy Policy Generator

**New Skill:** `/devtools:privacy-policy-generate`

Generates a privacy policy for GitHub Pages hosting.

#### Recommended Approach: Markdown for GitHub Pages

**Why Markdown:**
- GitHub Pages renders Markdown as HTML automatically
- Easy to maintain and update
- Version controlled with the project
- Google Play accepts GitHub Pages URLs

**Output Structure:**
```
docs/
├── privacy-policy.md          # Main privacy policy
├── terms-of-service.md        # Optional
└── _config.yml                # Jekyll config (if using theme)
```

**Result URL:** `https://hitoshura25.github.io/health-sync-app/privacy-policy`

#### Template Variables

The skill scans the project and fills in:

| Variable | Source |
|----------|--------|
| `{{APP_NAME}}` | AndroidManifest.xml or build.gradle |
| `{{PACKAGE_NAME}}` | AndroidManifest.xml |
| `{{DEVELOPER_NAME}}` | git config or user prompt |
| `{{CONTACT_EMAIL}}` | User prompt |
| `{{APP_TYPE}}` | User prompt (free/paid/ad-supported/open-source) |
| `{{HEALTH_DATA_TYPES}}` | Health Connect permissions in manifest |
| `{{THIRD_PARTY_SERVICES}}` | Dependencies in build.gradle |
| `{{LAST_UPDATED}}` | Current date |

#### Health App Specific Sections

For apps using Health Connect, the policy MUST include:

```markdown
## Health Data

This app integrates with **Health Connect** to access your health and fitness data.

**Health Data Types Accessed:**
- Steps (read/write)
- Heart rate (read)
- Sleep sessions (read)

**Purpose:** This app collects health data to [specific purpose].

**Data Storage:** Health data accessed through Health Connect remains on your 
device and is processed locally. We do not transmit your health data to 
external servers.

**Data Sharing:** Your health data is not shared with third parties.
```

#### Google Play Requirements for Health Apps

From [Play Console Help](https://support.google.com/googleplay/android-developer/answer/13996367):

1. Privacy policy must be on "active, publicly accessible, non-geofenced URL"
2. **Cannot be a PDF**
3. Must be non-editable (static page is fine)
4. Must include Health Connect data disclosure
5. Must complete Health Apps declaration form

#### Workflow

```
/devtools:privacy-policy-generate

1. Scan AndroidManifest.xml:
   - Package name, app name
   - Permissions (especially health/fitness)
   - Health Connect data types

2. Scan build.gradle:
   - Third-party SDKs (Firebase, AdMob, etc.)
   - Health Connect dependency

3. Prompt user for:
   - Developer/Company name
   - Contact email
   - App type (free/paid/ad-supported/open-source)
   - Data storage (local-only/cloud-sync/both)

4. Generate:
   - docs/privacy-policy.md
   - docs/PRIVACY_SETUP.md (instructions)

5. Output:
   - Preview URL: https://{username}.github.io/{repo}/privacy-policy
   - Checklist for Play Console
```

#### Example Generated Policy

```markdown
# Privacy Policy for Health Sync App

**Last updated:** December 12, 2025

Vinayak Menon built the Health Sync App as an Open Source app. This SERVICE 
is provided at no cost and is intended for use as is.

## Information Collection and Use

For a better experience while using our Service, we may require you to provide 
us with certain personally identifiable information. The information that we 
request will be retained on your device and is not collected by us in any way.

## Health Data

This app integrates with **Health Connect** to access your health and fitness data.

**Health Data Types Accessed:**
- Steps (read/write)
- Heart rate (read)
- Sleep sessions (read)
- Exercise sessions (read/write)

**Purpose:** This app collects health data to sync your fitness information 
across devices and provide insights into your health patterns.

**Data Storage:** Health data accessed through Health Connect remains on your 
device and is processed locally. We do not transmit your health data to 
external servers.

**Data Sharing:** Your health data is not shared with third parties.

## Third-Party Services

This app uses the following third-party services:

- **Health Connect** - [Privacy Policy](https://support.google.com/android/answer/12098244)

## Log Data

In case of an error in the app, we collect data called Log Data. This Log Data 
may include information such as your device's Internet Protocol ("IP") address, 
device name, operating system version, the configuration of the app, the time 
and date of your use of the Service, and other statistics.

## Security

We value your trust in providing us your Personal Information, thus we are 
striving to use commercially acceptable means of protecting it. But remember 
that no method of transmission over the internet, or method of electronic 
storage is 100% secure and reliable, and we cannot guarantee its absolute security.

## Children's Privacy

This Service does not address anyone under the age of 13. We do not knowingly 
collect personally identifiable information from children under 13.

## Changes to This Privacy Policy

We may update our Privacy Policy from time to time. Thus, you are advised to 
review this page periodically for any changes. We will notify you of any 
changes by posting the new Privacy Policy on this page.

## Contact Us

If you have any questions or suggestions about our Privacy Policy, do not 
hesitate to contact us at: contact@example.com

---

*This privacy policy is hosted on [GitHub Pages](https://hitoshura25.github.io/health-sync-app/privacy-policy)*
```

---

### 5.5 Privacy Policy Hosting Options

#### Option A: GitHub Pages (Recommended)

**Pros:**
- Free, version controlled
- Custom domain support
- Markdown renders automatically

**Setup:**
1. Create `docs/privacy-policy.md`
2. Enable GitHub Pages: Settings → Pages → Source: `docs/`
3. URL: `https://username.github.io/repo/privacy-policy`

#### Option B: External Services

| Service | Free Tier | API | Auto-Updates | Hosting |
|---------|-----------|-----|--------------|---------|
| **iubenda** | Yes | Yes | Yes | Yes |
| **TermsFeed** | Yes | Limited | Paid | Yes |
| **Termly** | Yes | No | Yes | Yes |

**iubenda API Integration:**
```javascript
// Create policy programmatically
POST https://www.iubenda.com/api/...
{
  "type": "create_privacy_policy",
  "args": {
    "privacy_policy": {
      "type": "mobile_app",
      "app_name": "Health Sync App"
    }
  }
}
// Returns: policy_url, embed_code
```

---

### 5.6 ProGuard Test Configuration

**Problem:** Test libraries in `proguard-rules.pro` increase APK size.

**Solution:** Separate test ProGuard file for release testing:

```kotlin
// app/build.gradle.kts
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Keep-all rules for test APK only
            testProguardFiles("proguard-rules-androidTest.pro")
        }
    }
    testBuildType = "release"
}
```

**`proguard-rules-androidTest.pro`:**
```proguard
# Keep EVERYTHING in test APK - we only care about signing, not size
-dontobfuscate
-dontoptimize
-dontshrink
-keep class ** { *; }
```

**Result:**
- App APK: Minified with release key ✅
- Test APK: Not minified, signed with release key ✅
- Both have matching signatures for instrumentation ✅

---

### 5.7 Version Management (Reusable)

**New Skill:** `/devtools:version-management`

A technology-agnostic version management system with adapters for different platforms.

#### Design: Cached Version File (Option 1)

Git tags remain the **source of truth**, but a committed `version.properties` file provides fast builds without git commands.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Version Flow                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  version.properties (committed)     ← Updated by release workflow   │
│       │                                                              │
│       ▼                                                              │
│  build.gradle.kts reads file        ← Fast, no git command          │
│       │                                                              │
│       ▼                                                              │
│  Release workflow:                                                   │
│    1. Calculate next version from git tags                          │
│    2. Update version.properties                                     │
│    3. Commit + tag + push                                           │
│    4. Build + deploy                                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

#### Files Structure

```
skills/
└── version-management/
    ├── SKILL.md
    └── templates/
        ├── version-manager.sh          # Core: git tag parsing, semver logic
        └── adapters/
            ├── gradle-version.sh       # Android/Gradle adapter
            ├── npm-version.sh          # npm adapter (future)
            └── python-version.sh       # Python adapter (future)
```

#### Core Script: `version-manager.sh`

```bash
#!/bin/bash
# Core version manager - technology agnostic
# Handles: tag parsing, semver calculation, version bumping

set -euo pipefail

# === CONFIGURATION ===
BASE_VERSION="${BASE_VERSION:-1.0}"
TAG_PREFIX="${TAG_PREFIX:-v}"

# === CORE FUNCTIONS ===

get_latest_version() {
    local prefix="${1:-$TAG_PREFIX}"
    git tag -l "${prefix}*" 2>/dev/null | 
        sed "s/^${prefix}//" | 
        sort -V | 
        tail -1 || echo "0.0.0"
}

bump_version() {
    local version="$1"
    local bump_type="${2:-patch}"
    
    IFS='.' read -r major minor patch <<< "$version"
    major="${major:-0}"; minor="${minor:-0}"; patch="${patch:-0}"
    
    case "$bump_type" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

generate_version() {
    local bump_type="${1:-patch}"
    local latest
    latest=$(get_latest_version)
    
    if [[ "$latest" == "0.0.0" ]]; then
        echo "${BASE_VERSION}.0"
    else
        bump_version "$latest" "$bump_type"
    fi
}

output_version() {
    local version="$1"
    local is_prerelease="${2:-false}"
    
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "version=$version" >> "$GITHUB_OUTPUT"
        echo "is-prerelease=$is_prerelease" >> "$GITHUB_OUTPUT"
        echo "tag=${TAG_PREFIX}${version}" >> "$GITHUB_OUTPUT"
    fi
    
    echo "$version"
}

main() {
    local command="${1:-generate}"
    local arg="${2:-patch}"
    
    case "$command" in
        generate) output_version "$(generate_version "$arg")" "false" ;;
        latest)   get_latest_version ;;
        bump)     bump_version "$(get_latest_version)" "$arg" ;;
        *)        echo "Usage: $0 {generate|latest|bump} [patch|minor|major]" >&2; exit 1 ;;
    esac
}

main "$@"
```

#### Gradle Adapter: `gradle-version.sh`

```bash
#!/bin/bash
# Gradle/Android version adapter

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/version-manager.sh"

# Convert semver to Android versionCode: "1.2.34" → 1002034
semver_to_version_code() {
    local version="$1"
    IFS='.' read -r major minor patch <<< "$version"
    echo $((major * 1000000 + minor * 1000 + patch))
}

# Update version.properties
update_version_properties() {
    local version="$1"
    local version_code
    version_code=$(semver_to_version_code "$version")
    
    cat > version.properties << VERSIONEOF
# Auto-generated by release workflow - do not edit manually
VERSION_NAME=$version
VERSION_CODE=$version_code
VERSIONEOF
    echo "Updated version.properties: VERSION_NAME=$version, VERSION_CODE=$version_code"
}

# Output Android-specific values to GitHub Actions
output_android_version() {
    local version="$1"
    local version_code
    version_code=$(semver_to_version_code "$version")
    
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "version-code=$version_code" >> "$GITHUB_OUTPUT"
    fi
}

main() {
    local command="${1:-generate}"
    shift || true
    
    case "$command" in
        generate)
            local version
            version=$(generate_version "${1:-patch}")
            output_version "$version" "false"
            output_android_version "$version"
            ;;
        update)
            local version="${1:-}"
            [[ -z "$version" ]] && version=$(get_latest_version)
            update_version_properties "$version"
            ;;
        version-code)
            local version="${1:-}"
            [[ -z "$version" ]] && version=$(get_latest_version)
            semver_to_version_code "$version"
            ;;
        *)
            # Delegate to core
            command="$command"
            source "$SCRIPT_DIR/version-manager.sh"
            main "$command" "$@"
            ;;
    esac
}

main "$@"
```

#### Gradle Configuration: `app/build.gradle.kts`

```kotlin
import java.util.Properties

// Read version from version.properties (fast, no git commands)
val versionProps = Properties().apply {
    val versionFile = rootProject.file("version.properties")
    if (versionFile.exists()) {
        versionFile.inputStream().use { load(it) }
    }
}

android {
    defaultConfig {
        versionName = versionProps.getProperty("VERSION_NAME", "0.0.1-dev")
        versionCode = versionProps.getProperty("VERSION_CODE", "1")?.toIntOrNull() ?: 1
    }
}
```

#### `version.properties` (Committed)

```properties
# Auto-generated by release workflow - do not edit manually
VERSION_NAME=1.0.0
VERSION_CODE=1000000
```

---

### 5.8 Split Workflows (Option D)

**Scope:** Internal track only (simplified for testing)

Two separate workflows with clear responsibilities:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Split Workflow Architecture                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  build.yml (CI)                                                     │
│  └── Triggered: PR, push to main                                    │
│  └── Jobs: build, test (unit + instrumented)                        │
│  └── Purpose: Validate code quality                                 │
│  └── NO deployment, NO tagging                                      │
│                                                                      │
│  release-internal.yml (Release)                                     │
│  └── Triggered: workflow_dispatch only (manual)                     │
│  └── Input: version_bump (patch/minor/major)                        │
│  └── Jobs:                                                          │
│      1. Calculate version from git tags                             │
│      2. Update version.properties                                   │
│      3. Commit version bump                                         │
│      4. Build release bundle                                        │
│      5. Upload artifact                                             │
│      6. Create git tag                                              │
│      7. Deploy to Play Store internal track                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

#### Workflow 1: `build.yml` (CI)

```yaml
name: Build & Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
      
      - name: Set up JDK
        uses: actions/setup-java@c5195efecf7bdfc987ee8bae7a71cb8b11521c00  # v4.7.0
        with:
          java-version: '17'
          distribution: 'temurin'
      
      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4
      
      - name: Build
        run: ./gradlew assembleRelease
      
      - name: Run Unit Tests
        run: ./gradlew test
      
      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.0
        with:
          name: test-results
          path: app/build/reports/tests/
```

#### Workflow 2: `release-internal.yml` (Release)

```yaml
name: Release to Internal Track

on:
  workflow_dispatch:
    inputs:
      version_bump:
        description: 'Version bump type'
        required: true
        type: choice
        options:
          - patch
          - minor
          - major
        default: 'patch'

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write  # For pushing commits and tags
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with:
          fetch-depth: 0  # Full history for tags
          token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Set up JDK
        uses: actions/setup-java@c5195efecf7bdfc987ee8bae7a71cb8b11521c00  # v4.7.0
        with:
          java-version: '17'
          distribution: 'temurin'
      
      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4
      
      - name: Calculate Version
        id: version
        run: |
          chmod +x scripts/gradle-version.sh
          scripts/gradle-version.sh generate ${{ inputs.version_bump }}
      
      - name: Update version.properties
        run: |
          scripts/gradle-version.sh update ${{ steps.version.outputs.version }}
      
      - name: Commit Version Bump
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add version.properties
          git commit -m "chore: release v${{ steps.version.outputs.version }}"
          git push origin main
      
      - name: Decode Keystore
        env:
          ENCODED_KEYSTORE: ${{ secrets.RELEASE_KEYSTORE_BASE64 }}
        run: |
          echo $ENCODED_KEYSTORE | base64 -d > app/release.jks
      
      - name: Build Release Bundle
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/app/release.jks
          SIGNING_KEY_STORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: ./gradlew bundleRelease
      
      - name: Upload Artifact
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.0
        with:
          name: release-${{ steps.version.outputs.tag }}
          path: app/build/outputs/bundle/release/app-release.aab
      
      - name: Create Git Tag
        run: |
          git tag -a ${{ steps.version.outputs.tag }} -m "Release ${{ steps.version.outputs.version }}"
          git push origin ${{ steps.version.outputs.tag }}
      
      - name: Deploy to Play Store (Internal)
        env:
          ANDROID_PUBLISHER_CREDENTIALS: ${{ secrets.SERVICE_ACCOUNT_JSON }}
        run: ./gradlew publishReleaseBundle --track internal
      
      - name: Cleanup Keystore
        if: always()
        run: rm -f app/release.jks
      
      - name: Release Summary
        run: |
          echo "## Release Complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Property | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|----------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Version | ${{ steps.version.outputs.version }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Tag | ${{ steps.version.outputs.tag }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Version Code | ${{ steps.version.outputs.version-code }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Track | Internal |" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Next Steps" >> $GITHUB_STEP_SUMMARY
          echo "1. Open Play Console - Internal Testing" >> $GITHUB_STEP_SUMMARY
          echo "2. Verify the new version is available" >> $GITHUB_STEP_SUMMARY
          echo "3. Add internal testers if needed" >> $GITHUB_STEP_SUMMARY
```

---

### 5.9 Play Store Setup Executor

**Skill:** `/devtools:android-playstore-setup`

**Purpose:** Execute Play Store setup based on scan results or interactive prompts.

**Scope:** Internal track deployment only (simplified)

#### Files Created/Modified

```
project/
├── version.properties                # Version tracking (committed)
├── app/build.gradle.kts              # Add GPP plugin + version reading
├── scripts/
│   ├── version-manager.sh            # Core version logic
│   └── gradle-version.sh             # Gradle adapter
├── src/main/play/
│   ├── release-notes/
│   │   └── en-US/
│   │       └── default.txt           # Release notes template
│   └── listings/
│       └── en-US/
│           ├── title.txt
│           ├── short-description.txt
│           └── full-description.txt
├── docs/
│   ├── privacy-policy.md             # Generated privacy policy
│   └── PLAY_CONSOLE_SETUP.md         # Setup checklist
└── .github/workflows/
    ├── build.yml                     # CI: build & test
    └── release-internal.yml          # Release: manual trigger
```

#### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `SERVICE_ACCOUNT_JSON` | Google Play service account JSON |
| `RELEASE_KEYSTORE_BASE64` | Base64 encoded keystore |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias |
| `KEY_PASSWORD` | Key password |

#### How to Release

1. Go to **Actions** then **Release to Internal Track**
2. Click **Run workflow**
3. Select version bump type (patch/minor/major)
4. Click **Run workflow**

The workflow automatically:
- Calculates next version from git tags
- Updates `version.properties`
- Commits the version bump
- Creates git tag
- Builds release bundle
- Deploys to Play Store internal track

---

### 5.10 Skill Dependency Graph

```
                    ┌─────────────────────────┐
                    │ android-playstore-scan  │
                    │    (analysis only)      │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  PLAY_CONSOLE_SETUP.md  │
                    │    (user reviews)       │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │ android-playstore-setup │
                    │    (orchestrator)       │
                    └───────────┬─────────────┘
                                │
        ┌───────────┬───────────┼───────────┬───────────┐
        ▼           ▼           ▼           ▼           ▼
┌─────────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│privacy-     │ │version- │ │signing- │ │workflow-│ │workflow-│
│policy-gen   │ │manager  │ │config   │ │build.yml│ │release  │
└─────────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

**Execution Order:**
1. `android-playstore-scan` generates PLAY_CONSOLE_SETUP.md
2. User reviews and edits configuration
3. `android-playstore-setup` orchestrates:
   - Version management scripts
   - Privacy policy generation
   - GPP plugin configuration
   - GitHub workflows (build.yml + release-internal.yml)
   - Signing configuration

---

## Summary of All Changes

### Critical (Security/Breaking)

| Issue | Files | Change |
|-------|-------|--------|
| Pin GitHub Actions | All workflow templates | Use commit SHA instead of tags |
| Test libs in ProGuard | `android-proguard-setup/SKILL.md` | Remove test library keep rules |
| `upload-artifact@v3` | All workflow templates | Update to v4 |
| `create-release@v1` | `android-workflow-production` | Use `gh release create` |
| **Migrate to GPP** | All workflow templates | Replace r0adkll with Gradle Play Publisher |

### High Priority (New Features)

| Issue | Files | Change |
|-------|-------|--------|
| Play Console Scanner | New skill | `/devtools:android-playstore-scan` |
| Play Store Setup | New skill | `/devtools:android-playstore-setup` |
| Privacy Policy Generator | New skill | `/devtools:privacy-policy-generate` |
| Play App Signing docs | Documentation | First upload workflow |
| Key mismatch recovery | Documentation | Upload key reset steps |

### Medium Priority

| Issue | Files | Change |
|-------|-------|--------|
| Task matching pattern | `android-signing-config/SKILL.md` | More specific regex |
| `userFraction` with completed | `android-workflow-beta/SKILL.md` | Don't set when completed |
| Permission error message | `validate-playstore.py` | More specific message |
| Env var prefix | `android-signing-config/SKILL.md` | Auto-detect from project |
| Python venv | `android-playstore-api-validation/SKILL.md` | Add venv setup |
| Gradle caching | All workflow templates | Add cache configuration |
| Debug symbols | All workflow templates | Add to upload action |
| Test before deploy | All workflow templates | Add test job |
| ProGuard test config | `android-proguard-setup/SKILL.md` | Add testProguardFiles |

### Documentation/UX

| Issue | Files | Change |
|-------|-------|--------|
| Track differences | Documentation | Add explanation |
| Manual upload requirement | Documentation | Add first-time setup guide |
| Workflow triggers | Workflow templates | workflow_dispatch for beta/prod |
| Keystore security | `android-keystore-generation/SKILL.md` | Add user-provided password option |

---

## Implementation Priority

1. **P0 (Security):** Pin GitHub Actions to SHAs, remove test libs from ProGuard
2. **P1 (Breaking):** Fix deprecated actions, userFraction issue, migrate to GPP
3. **P2 (New Features):** Privacy policy generator, Play Console scanner
4. **P3 (Quality):** Add tests before deploy, Gradle caching, debug symbols
5. **P4 (UX):** Env var prefix, documentation improvements
