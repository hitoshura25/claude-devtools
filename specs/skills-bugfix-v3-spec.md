# Skills Bug Fixes Implementation Spec v3

## Overview

This spec addresses bugs discovered during testing:
1. Organization name should prompt user with auto-detected default
2. Keytool shell command parsing issues (avoid `$()` in commands)
3. `jarsigner` → `apksigner` (missed in Step 5)
4. UI Automator 2.4 API corrections based on working code
5. Release build testing with matching signatures

---

## Issue 1: Organization Name - Always Prompt with Default

### File to Modify
`skills/android-keystore-generation/SKILL.md`

### Problem
Agent proceeds with auto-detected value without prompting user to confirm.

### Solution
Change the skill to ALWAYS prompt user, but provide auto-detected value as default.

### Changes

Replace the Organization Detection section with:

```markdown
### Organization Name

**ALWAYS prompt the user, but provide the auto-detected value as default.**

**Step 1: Detect organization from package name**
```bash
# Extract package name from build.gradle.kts
PACKAGE=$(grep "applicationId" app/build.gradle.kts | sed 's/.*"\(.*\)".*/\1/')
echo "Package: $PACKAGE"

# Extract second segment: com.{ORG}.app → ORG
ORG=$(echo $PACKAGE | cut -d. -f2)
echo "Detected organization: $ORG"
```

**Step 2: MANDATORY - Ask the user for confirmation**

⛔ **DO NOT SKIP THIS PROMPT**

Ask the user:
> "The detected organization name is **{ORG}**. 
> Press Enter to use this, or type a different name:"

Wait for user response. Use their input if provided, otherwise use the detected default.

**Step 3: Store the confirmed organization name**
```bash
ORGANIZATION="{confirmed_org_name}"
echo "Using organization: $ORGANIZATION"
```

**Why this matters:** The organization appears in the certificate's Distinguished Name.
While it doesn't affect app functionality, users may want to customize it.
```

---

## Issue 2: Keytool Shell Command Parsing

### File to Modify
`skills/android-keystore-generation/SKILL.md`

### Problem
Even with "separate commands" instruction, agent combines commands or uses `$()` which fails in Claude Code's bash environment:
```
(eval):1: parse error near `('
```

### Root Cause
Claude Code's bash tool may use `eval` or a shell that doesn't handle command substitution well in compound commands.

### Solution
Use file-based approach to avoid `$()` in variable assignments entirely.

### Changes

Replace Step 2 (Generate Production Keystore) with:

```markdown
### Step 2: Generate Production Keystore

**SECURITY:** This keystore is for CI/CD only. Never use locally.

**⚠️ IMPORTANT: Run each command in a SEPARATE bash call. Do NOT combine commands.**

**Step 2a: Generate password and save to file**
```bash
openssl rand -base64 24 | tr -d '/+=' | head -c 24 > /tmp/prod_password.txt
```

**Step 2b: Read and display the password**
```bash
cat /tmp/prod_password.txt
```
📝 **Copy this password now** - you'll need it for the keytool command and KEYSTORE_INFO.txt

**Step 2c: Generate the keystore**

Replace `{PASSWORD}` with the password from Step 2b, and `{ORGANIZATION}` with the confirmed organization name:

```bash
keytool -genkeypair -v \
  -keystore keystores/production-release.jks \
  -storetype PKCS12 \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "{PASSWORD}" \
  -keypass "{PASSWORD}" \
  -dname "CN=Android Release, OU=Android, O={ORGANIZATION}, C=US"
```

**If keytool prompts for confirmation**, type `yes` and press Enter.

**Step 2d: Verify keystore was created**
```bash
ls -la keystores/production-release.jks
```

**Expected output:**
```
-rw-------  1 user  staff  2557 Dec 11 10:30 keystores/production-release.jks
```
```

Apply the same pattern to Step 3 (Local Development Keystore), using `/tmp/local_password.txt`.

---

## Issue 3: jarsigner Still in Step 5

### File to Modify
`skills/android-release-validation/SKILL.md`

### Problem
Step 5 still uses `jarsigner -verify` which doesn't properly verify APK Signature Scheme v2/v3.

### Solution
Replace `jarsigner` with `apksigner` in Step 5.

### Changes

In Step 5 (Validate Signing), replace:

```bash
# Check APK signature
jarsigner -verify -verbose -certs app/build/outputs/apk/release/app-release.apk
```

With:

```bash
# Check APK signature (supports APK Signature Scheme v2/v3)
# Use apksigner from Android SDK build-tools
$ANDROID_HOME/build-tools/34.0.0/apksigner verify --verbose app/build/outputs/apk/release/app-release.apk

# Alternative if apksigner is in PATH:
# apksigner verify --verbose app/build/outputs/apk/release/app-release.apk
```

**Expected output:**
```
Verifies
Verified using v1 scheme (JAR signing): true
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
```

**Note:** `jarsigner -verify` only checks v1 signatures and may give incorrect results for modern APKs.

Also update the Troubleshooting section - replace:
```markdown
### "jarsigner not found"
Install JDK:
```

With:
```markdown
### "apksigner not found"
Ensure Android SDK build-tools are installed and in PATH:
```bash
# Check if apksigner exists
ls $ANDROID_HOME/build-tools/*/apksigner

# Add to PATH if needed
export PATH=$PATH:$ANDROID_HOME/build-tools/34.0.0/
```
```

---

## Issue 4: UI Automator 2.4 API Corrections

### File to Modify
`skills/android-e2e-testing-setup/SKILL.md`

### Problem
The documented API methods don't match the actual UI Automator 2.4.0-alpha05 API:
- `textAsString()` doesn't exist → use `text` property
- `withMessage()` doesn't exist → use Truth's `assertThat().isNotNull()` directly
- `activeWindow()` doesn't exist in the scope

### Solution
Update the SmokeTest.kt template based on the working code from health-sync-app.

### Changes

Replace the SmokeTest.kt template with:

```kotlin
package {PACKAGE_NAME}

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.uiAutomator
import androidx.test.uiautomator.UiAutomatorTestScope
import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Smoke test using modern UI Automator 2.4 API.
 *
 * This test works with BOTH debug and release APKs because UI Automator
 * interacts with the app externally (doesn't require debuggable build).
 *
 * Primary purpose: Validate app launches without crashing.
 * For release builds: Validates ProGuard/R8 didn't break critical code paths.
 *
 * @see https://developer.android.com/training/testing/other-components/ui-automator
 */
@RunWith(AndroidJUnit4::class)
class SmokeTest {

    companion object {
        private const val PACKAGE_NAME = "{PACKAGE_NAME}"
    }

    @Test
    fun appLaunches_doesNotCrash() = uiAutomator {
        // Start the app
        startApp(PACKAGE_NAME)

        // Wait for app to be visible
        waitForAppToBeVisible(PACKAGE_NAME)

        // Handle HealthConnect permission dialogs if they appear
        handleHealthConnectPermissions()

        // Verify app is running by checking for any element with our package
        val appElement = onElementOrNull(5000) {
            packageName == PACKAGE_NAME
        }

        assertThat(appElement).isNotNull()
    }

    @Test
    fun appLaunches_hasVisibleContent() = uiAutomator {
        // Start the app
        startApp(PACKAGE_NAME)
        waitForAppToBeVisible(PACKAGE_NAME)

        // Handle permissions
        handleHealthConnectPermissions()

        // Verify app has UI content (didn't crash to blank screen)
        val appStillRunning = onElementOrNull(2000) {
            packageName == PACKAGE_NAME
        }

        assertThat(appStillRunning).isNotNull()
    }

    // =========================================================================
    // HealthConnect Permission Handling
    // =========================================================================

    /**
     * Navigate through HealthConnect permission UI.
     *
     * HealthConnect has a multi-screen permission flow:
     * 1. Data permissions screen - toggle "Allow all" then click "Allow"
     * 2. Background access screen - click "Allow"
     */
    private fun UiAutomatorTestScope.handleHealthConnectPermissions() {
        // Screen 1: Data permissions ("fitness and wellness data")
        val dataPermScreen = onElementOrNull(3000) {
            text?.contains("fitness and wellness data") == true
        }

        if (dataPermScreen != null) {
            // Click "Allow all" toggle to enable all permissions
            onElementOrNull(1000) { text == "Allow all" }?.click()

            // Click "Allow" button at bottom
            onElement {
                text == "Allow" && className == "android.widget.Button"
            }.click()
        }

        // Screen 2: Background access ("access data in the background")
        val backgroundScreen = onElementOrNull(2000) {
            text?.contains("access data in the background") == true
        }

        if (backgroundScreen != null) {
            // Click "Allow" button
            onElement {
                text == "Allow" && className == "android.widget.Button"
            }.click()
        }
    }

    // =========================================================================
    // Standard Runtime Permissions (Optional)
    // =========================================================================

    /**
     * Handle standard Android runtime permission dialogs.
     */
    private fun UiAutomatorTestScope.handleRuntimePermissions() {
        val allowButton = onElementOrNull(1000) {
            text?.matches(Regex("(?i)allow|while using the app")) == true
        }
        allowButton?.click()
    }
}
```

**Key API corrections:**
| Incorrect (documentation) | Correct (actual API) |
|---------------------------|----------------------|
| `textAsString()` | `text` (nullable String property) |
| `textAsString() == "X"` | `text == "X"` |
| `textAsString()?.contains("X")` | `text?.contains("X") == true` |
| `assertThat(x).withMessage("...").isNotNull()` | `assertThat(x).isNotNull()` |
| `activeWindow().waitForStable()` | Remove - not available in scope |

---

## Issue 5: Release Build Testing with Matching Signatures

### Files to Modify
- `skills/android-e2e-testing-setup/SKILL.md`
- `skills/android-release-validation/SKILL.md`

### Problem
Test APK is signed with debug key, release APK is signed with release key. Android requires matching signatures for instrumentation:
```
SecurityException: Permission Denial: package does not have a signature matching the target
```

### Solution
Use `testBuildType = "release"` to make Gradle build and run tests against the release build type. This causes:
1. The app APK to be built as release (with ProGuard, release signing)
2. The test APK to also be signed with the release key
3. Both APKs have matching signatures

### Changes to `skills/android-e2e-testing-setup/SKILL.md`

Add a new section after dependencies:

```markdown
### Step 1b: Configure Test Build Type for Release Testing (Optional)

To run instrumented tests against the **release** build (for ProGuard validation), add this to `app/build.gradle.kts`:

```kotlin
android {
    // ... existing config ...
    
    // Change test build type from "debug" to "release"
    // This makes connectedAndroidTest run against release builds
    // IMPORTANT: Both app and test APK will be signed with release key
    testBuildType = "release"
}
```

**What this does:**
- `./gradlew connectedAndroidTest` now runs against release build
- Both app APK and test APK are signed with the same (release) key
- ProGuard/R8 runs on the app APK
- Tests validate the actual release build

**When to use this:**
- During release validation (before publishing)
- To catch ProGuard/R8 issues
- CI/CD release pipelines

**When NOT to use this:**
- Day-to-day development (debug builds are faster)
- When you don't have release signing configured locally

**To toggle back to debug testing:**
```kotlin
testBuildType = "debug"  // Or just remove the line (debug is default)
```
```

### Changes to `skills/android-release-validation/SKILL.md`

Replace Step 8 (Run Smoke Tests on Release Build) with:

```markdown
### Step 8: Run Smoke Tests on Release Build

**This is the key validation step for ProGuard/R8.**

#### Option A: Using testBuildType (Recommended)

Configure `app/build.gradle.kts` to test against release:

```kotlin
android {
    testBuildType = "release"
}
```

Then run:
```bash
./gradlew connectedAndroidTest
```

This:
- Builds release APK (with ProGuard)
- Builds test APK (signed with release key)
- Installs both and runs tests
- Both APKs have matching signatures ✓

**Expected output:**
```
> Task :app:connectedReleaseAndroidTest
Tests on Pixel_6_API_34 - 14

SmokeTest > appLaunches_doesNotCrash PASSED
SmokeTest > appLaunches_hasVisibleContent PASSED

2 tests, 2 passed, 0 failed
```

#### Option B: Manual Installation (If testBuildType doesn't work)

If you need to test a pre-built release APK:

```bash
# 1. Build release APK
./gradlew assembleRelease

# 2. Build release-signed test APK
# First, temporarily set testBuildType = "release" in build.gradle.kts
./gradlew assembleReleaseAndroidTest

# 3. Install both APKs
adb install app/build/outputs/apk/release/app-release.apk
adb install app/build/outputs/apk/androidTest/release/app-release-androidTest.apk

# 4. Run tests
adb shell am instrument -w \
  -e class {PACKAGE_NAME}.SmokeTest \
  {PACKAGE_NAME}.test/androidx.test.runner.AndroidJUnitRunner
```

#### If tests fail on release but pass on debug

This indicates ProGuard removed something needed:

1. Check logcat for the specific error:
   ```bash
   adb logcat -d | grep -E "ClassNotFoundException|NoSuchMethodError|NoSuchFieldError"
   ```

2. Add keep rules to `proguard-rules.pro`:
   ```proguard
   # Keep the class that was removed
   -keep class com.example.MissingClass { *; }
   
   # Keep classes used by reflection
   -keepclassmembers class * {
       @com.google.gson.annotations.SerializedName <fields>;
   }
   ```

3. Rebuild and re-test
```

Update the completion criteria:

```markdown
## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Device/emulator connected (`adb devices` shows device)
- [ ] `testBuildType = "release"` configured in build.gradle.kts (for release validation)
- [ ] `./gradlew connectedAndroidTest` succeeds with release build
- [ ] Release APK is signed (`apksigner verify` passes)
- [ ] ProGuard mapping exists: `app/build/outputs/mapping/release/mapping.txt`
- [ ] App launches without crashing on release build
- [ ] Smoke tests pass

**If no device available: FAIL. Do not skip.**
**If signature mismatch error: Verify testBuildType = "release" is set.**
```

---

## Summary of All Changes

| Issue | File(s) | Change |
|-------|---------|--------|
| 1. Org name prompt | `android-keystore-generation/SKILL.md` | Always prompt with auto-detected default |
| 2. Keytool parsing | `android-keystore-generation/SKILL.md` | File-based password, no `$()` |
| 3. jarsigner Step 5 | `android-release-validation/SKILL.md` | Replace with `apksigner` |
| 4. UI Automator API | `android-e2e-testing-setup/SKILL.md` | Use `text` not `textAsString()` |
| 5. Signature mismatch | Both skills | Use `testBuildType = "release"` |

---

## UI Automator 2.4 API Quick Reference

Based on working code:

```kotlin
// Finding elements
onElement { text == "Button" }                    // Find by exact text
onElement { text?.contains("partial") == true }   // Find by partial text
onElement { packageName == "com.example" }        // Find by package
onElement { className == "android.widget.Button" } // Find by class
onElementOrNull(timeoutMs) { ... }                // Returns null if not found

// Properties available in predicate
text: String?                    // Text content
packageName: String?             // Package name  
className: String?               // Android class name
contentDescription: String?      // Accessibility description
isClickable: Boolean
isEnabled: Boolean
isChecked: Boolean
isFocused: Boolean

// Actions
element.click()
element.longClick()
element.setText("text")

// Waiting
startApp(packageName)
waitForAppToBeVisible(packageName)
// Note: activeWindow() and waitForStable() not available in scope
```

---

## Testing After Implementation

### Test 1: Keystore Generation
```bash
/devtools:android-release-setup

# Verify:
# 1. User is prompted for organization name with default
# 2. No shell parsing errors
# 3. Both keystores generated
```

### Test 2: E2E Test Setup
```bash
/devtools:android-e2e-tests

# Verify:
# 1. SmokeTest.kt uses `text` not `textAsString()`
# 2. Compiles without errors
# 3. Tests pass on debug build
```

### Test 3: Release Validation
```bash
/devtools:android-release-validate

# Verify:
# 1. testBuildType = "release" is set
# 2. ./gradlew connectedAndroidTest works
# 3. Both APKs signed with same key (no signature mismatch)
# 4. Tests pass on release build
```
