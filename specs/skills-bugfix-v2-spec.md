# Skills Bug Fixes Implementation Spec v2

## Overview

This spec addresses bugs discovered during testing. Key changes:
1. Consistent certificate organization name defaults
2. Fix keytool command parsing issues
3. Use `apksigner` instead of `jarsigner`
4. Fix HealthConnect permission navigation with correct UI selectors
5. Consolidate on UI Automator approach for both debug and release testing
6. Remove broken `releaseTest` build type approach

---

## Issue 1: Inconsistent Organization Name Prompts

### File to Modify
`skills/android-keystore-generation/SKILL.md`

### Problem
Agent gives different suggestions each time (package name, GitHub, "Personal/Individual developer")

### Solution
Make the skill prescriptive with sensible defaults and clear detection logic.

### Changes

Find the section about Distinguished Name (DN) and replace with:

```markdown
### Certificate Distinguished Name (DN)

The certificate DN identifies who created the certificate. Use these defaults:

| Field | Value | Description |
|-------|-------|-------------|
| CN (Common Name) | `Android Release` | Standard for release certs |
| OU (Organizational Unit) | `Android` | App category |
| O (Organization) | *Derived from package name* | See detection logic below |
| C (Country) | `US` | 2-letter country code (change if needed) |

**Organization Detection Logic (in order):**

1. Extract from package name: `com.{organization}.app` → capitalize `{organization}`
   - Example: `com.hitoshura25.healthsync` → `Hitoshura25`
   - Example: `com.acmecorp.myapp` → `Acmecorp`
2. If package starts with `io.github.{username}` → use `{username}`
3. If cannot detect, use the literal string from package second segment

**Do NOT ask the user for organization name unless they want to override.**

**Example DN string:**
```
CN=Android Release, OU=Android, O=Hitoshura25, C=US
```

**For individual developers:** The organization can be your name or username. This doesn't affect app functionality - it only appears if someone inspects the certificate.
```

---

## Issue 2: Keytool Command Parse Error

### File to Modify
`skills/android-keystore-generation/SKILL.md`

### Problem
Compound shell commands with `$()` fail when agent runs them as single line:
```bash
PROD_PASSWORD=$(openssl rand ...) && keytool ...  # FAILS
```

### Solution
Document commands as separate steps, explicitly stating NOT to combine them.

### Changes

Replace Step 2 (Generate Production Keystore) with:

```markdown
### Step 2: Generate Production Keystore

**IMPORTANT: Run each command separately. Do NOT combine with `&&`.**

**Step 2a: Generate secure password**
```bash
PROD_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
```

**Step 2b: Display and save the password**
```bash
echo "Production keystore password: $PROD_PASSWORD"
```
⚠️ **Save this password immediately** - you'll need it for KEYSTORE_INFO.txt

**Step 2c: Generate the keystore**
```bash
keytool -genkeypair -v \
  -keystore keystores/production-release.jks \
  -storetype PKCS12 \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$PROD_PASSWORD" \
  -keypass "$PROD_PASSWORD" \
  -dname "CN=Android Release, OU=Android, O={ORGANIZATION}, C=US"
```

Replace `{ORGANIZATION}` with the detected organization name.

**If keytool prompts for confirmation**, type `yes` and press Enter.

**Expected output:**
```
Generating 2,048 bit RSA key pair and self-signed certificate (SHA256withRSA) with a validity of 10,000 days
	for: CN=Android Release, OU=Android, O=YourOrg, C=US
[Storing keystores/production-release.jks]
```
```

Apply the same pattern to Step 3 (Local Development Keystore).

---

## Issue 3: jarsigner vs apksigner

### Files to Modify
- `skills/android-signing-config/SKILL.md`
- `skills/android-release-validation/SKILL.md`
- `commands/devtools/android-release-setup.md`
- `commands/devtools/android-release-validate.md`

### Problem
Modern APKs use APK Signature Scheme v2/v3, which `jarsigner` doesn't verify correctly.

### Solution
Replace all `jarsigner -verify` with `apksigner verify`.

### Changes

**In all files, replace:**
```bash
jarsigner -verify -verbose -certs app/build/outputs/apk/release/app-release.apk
```

**With:**
```bash
# Verify APK signature (supports APK Signature Scheme v2/v3)
$ANDROID_HOME/build-tools/34.0.0/apksigner verify --verbose app/build/outputs/apk/release/app-release.apk

# Or if apksigner is in PATH:
apksigner verify --verbose app/build/outputs/apk/release/app-release.apk
```

**Expected output:**
```
Verifies
Verified using v1 scheme (JAR signing): true
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
```

**Also update completion criteria** from:
- `jarsigner -verify` confirms APK is signed

To:
- `apksigner verify` confirms APK is signed (v2/v3 schemes)

---

## Issue 4: HealthConnect Permission Navigation + Modern UI Automator 2.4 API

### Files to Modify
- `skills/android-e2e-testing-setup/SKILL.md`

### Problem
1. UI Automator code doesn't interact with HealthConnect permission screens correctly
2. Using deprecated `device.waitForIdle()` instead of modern API

### Solution
1. Update to UI Automator 2.4 modern API with `uiAutomator { }` scope
2. Use built-in `onElement { }` with automatic waiting
3. Use `watchFor()` for permission dialogs
4. Use `waitForAppToBeVisible()` and `waitForStable()` instead of `waitForIdle()`

### Changes

**Update dependency version in skill:**

```kotlin
// Use UI Automator 2.4+ for modern API
androidTestImplementation("androidx.test.uiautomator:uiautomator:2.4.0-alpha05")
```

**Replace entire SmokeTest.kt with modern UI Automator 2.4 approach:**

```kotlin
package {PACKAGE_NAME}

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.uiAutomator
import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Smoke test using modern UI Automator 2.4 API.
 * 
 * This test works with BOTH debug and release APKs because UI Automator
 * interacts with the app externally (doesn't require debuggable build).
 * 
 * Uses the modern `uiAutomator { }` DSL which provides:
 * - Built-in waiting via `onElement { }` (default 10s timeout)
 * - `waitForAppToBeVisible()` instead of deprecated `waitForIdle()`
 * - `watchFor()` for handling permission dialogs
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
        
        // Wait for app to be visible (replaces waitForIdle)
        waitForAppToBeVisible(PACKAGE_NAME)
        
        // Handle HealthConnect permission dialogs if they appear
        handleHealthConnectPermissions()
        
        // Verify app is running by checking for any element with our package
        val appElement = onElementOrNull(5000) { 
            packageName == PACKAGE_NAME 
        }
        
        assertThat(appElement)
            .withMessage("App should be visible after launch")
            .isNotNull()
    }
    
    @Test
    fun appLaunches_hasVisibleContent() = uiAutomator {
        // Start the app
        startApp(PACKAGE_NAME)
        waitForAppToBeVisible(PACKAGE_NAME)
        
        // Handle permissions
        handleHealthConnectPermissions()
        
        // Wait for UI to stabilize
        activeWindow().waitForStable()
        
        // Verify there's content (the app didn't crash to a blank screen)
        val hasContent = onElementOrNull(3000) { 
            packageName == PACKAGE_NAME && isClickable 
        }
        
        assertThat(hasContent)
            .withMessage("App should have interactive content")
            .isNotNull()
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
     * 
     * Based on actual UI screenshots from the HealthConnect permission flow.
     */
    private fun UiAutomatorTestScope.handleHealthConnectPermissions() {
        // Screen 1: Data permissions ("fitness and wellness data")
        // Check if we're on this screen
        val dataPermScreen = onElementOrNull(3000) { 
            textAsString()?.contains("fitness and wellness data") == true 
        }
        
        if (dataPermScreen != null) {
            // Click "Allow all" toggle to enable all permissions
            onElementOrNull(1000) { textAsString() == "Allow all" }?.click()
            
            // Click "Allow" button at bottom
            onElement { textAsString() == "Allow" && className == "android.widget.Button" }.click()
        }
        
        // Screen 2: Background access ("access data in the background")
        val backgroundScreen = onElementOrNull(2000) { 
            textAsString()?.contains("access data in the background") == true 
        }
        
        if (backgroundScreen != null) {
            // Click "Allow" button
            onElement { textAsString() == "Allow" && className == "android.widget.Button" }.click()
        }
    }
}
```

**Key improvements in modern API:**

| Old API (deprecated) | New API (UI Automator 2.4) |
|---------------------|----------------------------|
| `device.waitForIdle()` | `waitForAppToBeVisible()` or `activeWindow().waitForStable()` |
| `device.findObject(UiSelector().text("X"))` | `onElement { textAsString() == "X" }` |
| `element.exists()` check + click | `onElementOrNull { }?.click()` |
| Manual timeout loops | Built-in timeout in `onElement(timeoutMs)` |
| `UiDevice.getInstance(...)` | `uiAutomator { }` scope |

**Note about `onElement` timeout:**
- `onElement { }` has a default 10-second timeout
- `onElement(5000) { }` for custom timeout (5 seconds)
- `onElementOrNull { }` returns null instead of throwing if not found

---

## Issue 5: Consolidate on UI Automator 2.4 (Remove releaseTest)

### Files to Modify
- `skills/android-e2e-testing-setup/SKILL.md` (major rewrite)
- `skills/android-release-validation/SKILL.md` (major rewrite)
- `commands/devtools/android-e2e-tests.md`
- `commands/devtools/android-release-validate.md`

### Problem
1. `releaseTest` build type doesn't create test tasks automatically
2. Making release debuggable disables ProGuard optimizations
3. Espresso requires debuggable builds, but we need to test actual release APK
4. Using deprecated `waitForIdle()` instead of modern API

### Solution
Use UI Automator 2.4 for all testing. The modern API provides:
- Works with non-debuggable APKs
- `uiAutomator { }` test scope for cleaner code
- Built-in waiting via `onElement { }` (no more `waitForIdle()`)
- `waitForAppToBeVisible()` and `waitForStable()` for explicit state management
- Can interact with system UI (permissions)

### Revised Architecture

```
Testing Approach (UI Automator 2.4):
====================================

1. Build the APK (debug or release)
2. Install the APK on device
3. Build and install the TEST APK (always debug - it's just the test runner)
4. Run UI Automator tests against the installed app APK

The test APK is separate from the app APK.
Tests use UI Automator 2.4's modern API to interact with the app externally.

Key APIs:
- uiAutomator { } - Test scope
- startApp(packageName) - Launch app
- waitForAppToBeVisible() - Wait for app (replaces waitForIdle)
- onElement { } - Find element with built-in waiting
- activeWindow().waitForStable() - Wait for UI stability
```

### Changes to `skills/android-e2e-testing-setup/SKILL.md`

**Remove the `releaseTest` build type section entirely.**

**Update dependencies to use UI Automator 2.4:**

```markdown
### Step 1: Add Dependencies

Update `app/build.gradle.kts`:

```kotlin
dependencies {
    // UI Automator 2.4 - Modern API with built-in waiting
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.4.0-alpha05")
    
    // AndroidX Test
    androidTestImplementation("androidx.test:core:1.5.0")
    androidTestImplementation("androidx.test:runner:1.5.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    
    // Truth assertions
    androidTestImplementation("com.google.truth:truth:1.1.5")
}
```

**Note:** UI Automator 2.4 introduces a modern Kotlin DSL. See:
https://developer.android.com/training/testing/other-components/ui-automator
```

**Replace SmokeTest.kt template with modern UI Automator 2.4:**

```markdown
### Step 2: Create Smoke Test

Create `app/src/androidTest/kotlin/{package_path}/SmokeTest.kt`:

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
 * Modern API features used:
 * - `uiAutomator { }` scope for cleaner test code
 * - `onElement { }` with built-in 10s timeout (no waitForIdle needed)
 * - `waitForAppToBeVisible()` for explicit app state management
 * - `waitForStable()` for UI stability
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
        
        // Wait for app to be visible (modern replacement for waitForIdle)
        waitForAppToBeVisible(PACKAGE_NAME)
        
        // Handle HealthConnect permission dialogs if they appear
        handleHealthConnectPermissions()
        
        // Verify app is running by checking for any element with our package
        // onElementOrNull has built-in timeout, returns null if not found
        val appElement = onElementOrNull(5000) { 
            packageName == PACKAGE_NAME 
        }
        
        assertThat(appElement)
            .withMessage("App should be visible after launch")
            .isNotNull()
    }
    
    @Test
    fun appLaunches_hasVisibleContent() = uiAutomator {
        // Start the app
        startApp(PACKAGE_NAME)
        waitForAppToBeVisible(PACKAGE_NAME)
        
        // Handle permissions
        handleHealthConnectPermissions()
        
        // Wait for UI to stabilize (use when you know UI might be animating)
        activeWindow().waitForStable()
        
        // Verify there's interactive content (app didn't crash to blank screen)
        val hasContent = onElementOrNull(3000) { 
            packageName == PACKAGE_NAME && isClickable 
        }
        
        assertThat(hasContent)
            .withMessage("App should have interactive content")
            .isNotNull()
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
            textAsString()?.contains("fitness and wellness data") == true 
        }
        
        if (dataPermScreen != null) {
            // Click "Allow all" toggle to enable all permissions
            onElementOrNull(1000) { textAsString() == "Allow all" }?.click()
            
            // Click "Allow" button at bottom
            onElement { 
                textAsString() == "Allow" && className == "android.widget.Button" 
            }.click()
        }
        
        // Screen 2: Background access ("access data in the background")
        val backgroundScreen = onElementOrNull(2000) { 
            textAsString()?.contains("access data in the background") == true 
        }
        
        if (backgroundScreen != null) {
            // Click "Allow" button
            onElement { 
                textAsString() == "Allow" && className == "android.widget.Button" 
            }.click()
        }
    }
    
    // =========================================================================
    // Standard Runtime Permissions (Optional)
    // =========================================================================
    
    /**
     * Handle standard Android runtime permission dialogs.
     * Call this if your app requests permissions like camera, location, etc.
     * 
     * Alternative: Use watchFor(PermissionDialog) { clickAllow() }
     */
    private fun UiAutomatorTestScope.handleRuntimePermissions() {
        // Look for standard permission dialog allow button
        val allowButton = onElementOrNull(1000) { 
            textAsString()?.matches(Regex("(?i)allow|while using the app")) == true 
        }
        allowButton?.click()
    }
}
```

**Replace {PACKAGE_NAME} with the actual package name (e.g., `com.hitoshura25.healthsync`).**

**Note:** The `UiAutomatorTestScope` extension functions allow accessing the scope's methods like `onElement` from within helper functions.
```

### Changes to `skills/android-release-validation/SKILL.md`

**Replace the E2E test section with:**

```markdown
### Step 8: Run Smoke Tests on Release Build

**This is the key validation step for ProGuard/R8.**

The approach:
1. Install the release APK (with ProGuard enabled)
2. Run UI Automator tests against it (test APK is separate)

```bash
# Step 8a: Uninstall any existing version
adb uninstall {PACKAGE_NAME} || true

# Step 8b: Install the RELEASE APK
adb install app/build/outputs/apk/release/app-release.apk

# Step 8c: Build the test APK (this is always debug, it's just the test runner)
./gradlew assembleDebugAndroidTest

# Step 8d: Install the test APK
adb install app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk

# Step 8e: Run the smoke tests against the release app
adb shell am instrument -w \
  -e class {PACKAGE_NAME}.SmokeTest \
  {PACKAGE_NAME}.test/androidx.test.runner.AndroidJUnitRunner
```

**Expected output:**
```
{PACKAGE_NAME}.SmokeTest:
  appLaunches_doesNotCrash: OK (3.2s)
  appLaunches_hasVisibleContent: OK (2.8s)

OK (2 tests)
```

**If tests fail:**
1. Check logcat for crash details: `adb logcat -d | grep -i crash`
2. Common cause: ProGuard removed a class used by reflection
3. Add keep rules to `proguard-rules.pro`
4. Rebuild release APK and re-test
```

**Update completion criteria:**

```markdown
## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Device/emulator connected (`adb devices` shows device)
- [ ] `./gradlew assembleRelease` succeeds
- [ ] Release APK exists and is signed (`apksigner verify` passes)
- [ ] ProGuard mapping exists: `app/build/outputs/mapping/release/mapping.txt`
- [ ] Release APK installed on device
- [ ] Smoke tests pass when run against release APK
- [ ] App launches without crashing on release build

**If no device available: FAIL. Do not skip.**
**If tests fail on release but pass on debug: ProGuard issue - add keep rules.**
```

### Changes to Commands

**`commands/devtools/android-e2e-tests.md`:**

Remove `releaseTest` from completion criteria:

```markdown
## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] UI Automator 2.4 dependency in `app/build.gradle.kts`
- [ ] `SmokeTest.kt` exists in androidTest directory using modern `uiAutomator { }` API
- [ ] `./gradlew connectedDebugAndroidTest` passes
- [ ] Device/emulator was used (tests cannot run without one)
- [ ] HealthConnect permissions handled automatically by test
```

**`commands/devtools/android-release-validate.md`:**

```markdown
## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Device connected (`adb devices` shows device)
- [ ] Release APK built and signed
- [ ] `apksigner verify` confirms valid signature
- [ ] Release APK installed on device
- [ ] Smoke tests pass against release APK (via `adb shell am instrument`)
- [ ] ProGuard mapping file exists
```

---

## Issue 6: Remove releaseTest Build Type

### Files to Modify
- `skills/android-e2e-testing-setup/SKILL.md`

### Changes

**Remove entirely** the section about `releaseTest` build type:

```kotlin
// REMOVE THIS ENTIRE SECTION:
create("releaseTest") {
    initWith(getByName("release"))
    isDebuggable = true
    signingConfig = signingConfigs.getByName("release")
}
```

The `releaseTest` approach doesn't work because:
1. Making it debuggable disables ProGuard optimizations
2. Test tasks aren't automatically created for custom build types
3. It defeats the purpose of testing the actual release build

---

## Summary of All Changes

| Issue | File(s) | Change |
|-------|---------|--------|
| 1. Org name | `android-keystore-generation/SKILL.md` | Prescriptive defaults, detection logic |
| 2. Keytool commands | `android-keystore-generation/SKILL.md` | Separate commands, not compound |
| 3. apksigner | Multiple files | Replace `jarsigner` with `apksigner` |
| 4. HealthConnect + Modern API | `android-e2e-testing-setup/SKILL.md` | UI Automator 2.4 DSL, correct selectors |
| 5. UI Automator 2.4 | `android-e2e-testing-setup/SKILL.md`, `android-release-validation/SKILL.md` | Modern `uiAutomator { }` scope, `onElement`, `waitForAppToBeVisible` |
| 6. Remove releaseTest | `android-e2e-testing-setup/SKILL.md` | Remove broken build type |

### UI Automator API Migration Summary

| Old API (deprecated) | New API (UI Automator 2.4) |
|---------------------|----------------------------|
| `UiDevice.getInstance(...)` | `uiAutomator { }` scope |
| `device.waitForIdle()` | `waitForAppToBeVisible()` or `activeWindow().waitForStable()` |
| `device.findObject(UiSelector().text("X"))` | `onElement { textAsString() == "X" }` |
| Manual timeout loops | Built-in timeout: `onElement(5000) { }` |
| `element.exists()` + click | `onElementOrNull { }?.click()` |
| `device.findObject(By.pkg(...))` | `onElement { packageName == "..." }` |

**Key benefits of UI Automator 2.4:**
- Cleaner Kotlin DSL
- Built-in waiting (no more `waitForIdle()` everywhere)
- More readable predicates
- Better null handling with `onElementOrNull`

---

## Testing After Implementation

### Test E2E Setup
```bash
# Run the command
/devtools:android-e2e-tests

# Verify:
# 1. SmokeTest.kt uses `uiAutomator { }` scope
# 2. Uses `onElement { }` not `findObject()`
# 3. Uses `waitForAppToBeVisible()` not `waitForIdle()`
# 4. No releaseTest build type
# 5. ./gradlew connectedDebugAndroidTest passes
# 6. HealthConnect permissions navigated automatically
```

### Test Release Validation
```bash
# Run the command
/devtools:android-release-validate

# Verify:
# 1. Release APK built
# 2. apksigner verify passes (not jarsigner)
# 3. Release APK installed on device
# 4. Smoke tests run against release APK via adb shell am instrument
# 5. Tests pass (ProGuard didn't break app)
```

### Test Keystore Generation
```bash
# Run the command
/devtools:android-release-setup

# Verify:
# 1. Organization auto-detected from package name
# 2. Keytool commands run separately without parse errors
# 3. Both keystores generated
```
