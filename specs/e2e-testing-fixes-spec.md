# E2E Testing and Validation Fixes Implementation Spec

## Overview

This spec addresses issues discovered during testing of the Android skills. The changes focus on:
1. Removing redundant `gradle.properties.template`
2. Simplifying E2E tests to smoke tests only
3. Adding `releaseTest` build type for testing ProGuard builds
4. Adding UI Automator for system permission handling (HealthConnect, etc.)
5. Enforcing device/emulator requirement (no skipping)

## Issue Summary

| Issue | Problem | Solution |
|-------|---------|----------|
| Redundant template | `gradle.properties.template` duplicates `KEYSTORE_INFO.txt` | Remove template creation |
| Generic tests | Tests use placeholder IDs that don't compile | Use `android.R.id.content` (universal) |
| Skipped verification | Agent skips `connectedAndroidTest` | Stronger language + prerequisite check |
| No device = skip | Agent skips validation without device | Hard fail, offer emulator startup |
| No release testing | Can't test ProGuard with instrumented tests | Add `releaseTest` build type |
| Permission dialogs | HealthConnect blocks test execution | UI Automator to navigate system UI |

---

## Task 1: Remove gradle.properties.template

### Files to Modify

**File:** `skills/android-signing-config/SKILL.md`

**Action:** Remove any section that creates `gradle.properties.template`

**Reason:** `KEYSTORE_INFO.txt` already contains all the information needed. The template is redundant.

### Changes

Find and remove any content related to creating `gradle.properties.template`. This includes:
- Step that creates the template file
- References to the template in completion criteria
- References in outputs table

Keep the `KEYSTORE_INFO.txt` creation - that's the source of truth for credentials.

---

## Task 2: Update E2E Testing Skill - Smoke Test Only

### Files to Modify

**File:** `skills/android-e2e-testing-setup/SKILL.md`

### Goal

Replace complex test generation with a simple smoke test that:
1. Verifies app launches without crashing
2. Uses `android.R.id.content` (exists in ALL activities, no analysis needed)
3. Includes UI Automator for system permission handling

### Changes

#### 2.1: Update Dependencies Section

Replace the dependencies section with:

```kotlin
dependencies {
    // Espresso core
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    
    // AndroidX Test
    androidTestImplementation("androidx.test:core:1.5.0")
    androidTestImplementation("androidx.test:core-ktx:1.5.0")
    androidTestImplementation("androidx.test:runner:1.5.2")
    androidTestImplementation("androidx.test:rules:1.5.0")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.ext:junit-ktx:1.1.5")
    
    // UI Automator - for system permission dialogs
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
    
    // Truth assertions (cleaner than JUnit assertions)
    androidTestImplementation("com.google.truth:truth:1.1.5")
}
```

#### 2.2: Add releaseTest Build Type

Add this section to configure a testable release build:

```markdown
### Configure releaseTest Build Type

Add a `releaseTest` build type that mirrors release but is debuggable (required for instrumentation):

```kotlin
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
        
        // Testable release build - same as release but debuggable
        create("releaseTest") {
            initWith(getByName("release"))
            isDebuggable = true  // Required for instrumentation tests
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

This allows running `./gradlew connectedReleaseTestAndroidTest` to test ProGuard builds.
```

#### 2.3: Replace Test Generation with Smoke Test

Remove all complex test generation (MainActivityTest, navigation tests, interaction tests).

Replace with this single smoke test template:

```markdown
### Create Smoke Test

Create `app/src/androidTest/kotlin/{package_path}/SmokeTest.kt`:

```kotlin
package {PACKAGE_NAME}

import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.withId
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiSelector
import com.google.common.truth.Truth.assertThat
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Smoke test to verify app launches without crashing.
 * 
 * Primary purpose: Validate ProGuard/R8 didn't break critical code paths.
 * This test uses android.R.id.content which exists in ALL activities,
 * so no project-specific view IDs are needed.
 */
@RunWith(AndroidJUnit4::class)
class SmokeTest {
    
    private lateinit var device: UiDevice
    
    @get:Rule
    val activityRule = ActivityScenarioRule({MAIN_ACTIVITY}::class.java)
    
    @Before
    fun setUp() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        // Handle any system permission dialogs before tests run
        handleSystemPermissions()
    }
    
    @Test
    fun appLaunches_doesNotCrash() {
        // If we reach this point, the app launched successfully
        // ProGuard didn't break any critical initialization code
        activityRule.scenario.onActivity { activity ->
            assertThat(activity).isNotNull()
            assertThat(activity.isFinishing).isFalse()
        }
    }
    
    @Test
    fun mainActivity_contentIsDisplayed() {
        // android.R.id.content is the root view container of every Activity
        // This verifies the Activity inflated its layout without crashing
        onView(withId(android.R.id.content))
            .check(matches(isDisplayed()))
    }
    
    // =========================================================================
    // System Permission Handling
    // =========================================================================
    
    /**
     * Handle system permission dialogs that may appear on app launch.
     * 
     * Uses UI Automator to interact with system UI outside the app.
     * Customize this method for your app's specific permission flows.
     */
    private fun handleSystemPermissions() {
        device.waitForIdle(2000)
        
        // Handle HealthConnect permissions if present
        handleHealthConnectPermissions()
        
        // Handle standard Android runtime permissions if present
        handleRuntimePermissions()
    }
    
    /**
     * Navigate through HealthConnect permission UI if it appears.
     */
    private fun handleHealthConnectPermissions() {
        val healthConnectUI = device.findObject(
            UiSelector().textContains("Health Connect")
        )
        
        if (healthConnectUI.exists()) {
            // Try "Allow all" or "Select all" first
            val allowAll = device.findObject(
                UiSelector().textMatches("(?i)allow all|select all")
            )
            if (allowAll.exists()) {
                allowAll.click()
                device.waitForIdle(1000)
            }
            
            // Look for individual permission toggles and enable them
            // This handles cases where there's no "allow all" button
            val toggles = device.findObjects(
                UiSelector().className("android.widget.Switch")
            )
            // Note: findObjects returns UiObject2 list in newer API
            // For UiAutomator 2.x, iterate and click unchecked toggles
            
            // Click the confirm/allow/done button
            val confirmButton = device.findObject(
                UiSelector().textMatches("(?i)allow|done|confirm|next|save")
            )
            if (confirmButton.exists()) {
                confirmButton.click()
                device.waitForIdle(1000)
            }
            
            // Some flows have multiple screens - try again
            val secondConfirm = device.findObject(
                UiSelector().textMatches("(?i)allow|done|confirm|finish")
            )
            if (secondConfirm.exists()) {
                secondConfirm.click()
                device.waitForIdle(1000)
            }
        }
    }
    
    /**
     * Handle standard Android runtime permission dialogs.
     */
    private fun handleRuntimePermissions() {
        // Handle "Allow" button on standard permission dialogs
        val allowButton = device.findObject(
            UiSelector()
                .resourceId("com.android.permissioncontroller:id/permission_allow_button")
        )
        if (allowButton.exists()) {
            allowButton.click()
            device.waitForIdle(500)
        }
        
        // Alternative: text-based matching for different Android versions
        val allowByText = device.findObject(
            UiSelector().textMatches("(?i)allow|while using the app")
        )
        if (allowByText.exists()) {
            allowByText.click()
            device.waitForIdle(500)
        }
    }
}
```

**Replace `{PACKAGE_NAME}` with the actual package name from the project.**
**Replace `{MAIN_ACTIVITY}` with the actual main activity class name.**

To find the main activity:
```bash
grep -r "android.intent.action.MAIN" app/src/main/AndroidManifest.xml
```
```

#### 2.4: Update Verification Section

Replace verification section with:

```markdown
## Verification (MANDATORY)

⛔ **DO NOT SKIP THIS STEP**

### Prerequisite: Device/Emulator Required

First, verify a device or emulator is available:

```bash
adb devices
```

**If no devices listed:**
1. Start an emulator:
   ```bash
   # List available AVDs
   emulator -list-avds
   
   # Start an emulator (replace with actual AVD name)
   emulator -avd Pixel_6_API_34 &
   
   # Wait for device to be ready
   adb wait-for-device
   ```
2. Or connect a physical device with USB debugging enabled
3. Re-run `adb devices` to confirm

**If no device/emulator available, STOP. Inform user this skill cannot complete without a device.**

### Run Tests

```bash
# Run debug tests first
./gradlew connectedDebugAndroidTest
```

**If tests fail:**
1. Read the error message carefully
2. Fix compilation errors (usually import issues)
3. Fix test failures (adjust permission handling if needed)
4. Re-run until tests pass

**Only proceed to completion when tests pass.**

### Expected Output

```
> Task :app:connectedDebugAndroidTest
Tests on Pixel_6_API_34 - 14

SmokeTest > appLaunches_doesNotCrash PASSED
SmokeTest > mainActivity_contentIsDisplayed PASSED

2 tests, 2 passed, 0 failed
```
```

#### 2.5: Update Completion Criteria

```markdown
## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Espresso dependencies added to `app/build.gradle.kts`
- [ ] UI Automator dependency added to `app/build.gradle.kts`
- [ ] `releaseTest` build type configured in `app/build.gradle.kts`
- [ ] `app/src/androidTest/kotlin/{package}/SmokeTest.kt` exists
- [ ] `./gradlew connectedDebugAndroidTest` executes successfully
- [ ] At least 2 tests pass (appLaunches, contentIsDisplayed)

**If tests fail, fix them before marking complete.**
```

#### 2.6: Remove Unnecessary Content

Remove these sections/files as they're no longer needed:
- Complex test generation (MainActivityTest, navigation tests)
- TestUtils.kt (not needed for smoke test)
- ScreenshotUtil.kt (not needed for smoke test)
- BaseTest.kt (permission handling is in SmokeTest itself)

---

## Task 3: Update Release Validation Skill

### Files to Modify

**File:** `skills/android-release-validation/SKILL.md`

### Goal

1. Enforce device requirement (no skipping)
2. Use `connectedReleaseTestAndroidTest` for ProGuard validation
3. Add emulator startup guidance

### Changes

#### 3.1: Add Device Prerequisite Check at Start

Add this at the very beginning of the Process section:

```markdown
## Prerequisites Check (MANDATORY - DO FIRST)

### Device/Emulator Requirement

⛔ **This skill REQUIRES a connected device or running emulator. It cannot be skipped.**

Check for connected devices:
```bash
adb devices
```

**If output shows "List of devices attached" with no devices:**

Option 1 - Start an emulator:
```bash
# List available AVDs
emulator -list-avds

# Start emulator in background
emulator -avd <AVD_NAME> -no-snapshot-save &

# Wait for device to be ready (may take 1-2 minutes)
adb wait-for-device
adb shell getprop sys.boot_completed  # Should return "1" when ready
```

Option 2 - Connect physical device:
1. Enable Developer Options on device
2. Enable USB Debugging
3. Connect via USB
4. Accept debugging prompt on device

**DO NOT PROCEED until `adb devices` shows a connected device.**

If user cannot provide a device/emulator:
- ❌ STOP - Inform user this skill cannot complete
- ❌ DO NOT skip validation steps
- ❌ DO NOT mark skill as complete
```

#### 3.2: Update Test Command

Change from:
```bash
./gradlew connectedReleaseAndroidTest
```

To:
```bash
./gradlew connectedReleaseTestAndroidTest
```

Explanation: `releaseTest` is a custom build type configured in the E2E testing skill that mirrors release but is debuggable (required for instrumentation tests).

#### 3.3: Update Completion Criteria

```markdown
## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Device/emulator connected (`adb devices` shows device)
- [ ] `./gradlew assembleReleaseTest` succeeds
- [ ] `./gradlew connectedReleaseTestAndroidTest` succeeds
- [ ] All smoke tests pass on releaseTest build
- [ ] ProGuard mapping exists: `app/build/outputs/mapping/releaseTest/mapping.txt`
- [ ] APK is signed: `jarsigner -verify` succeeds

**If no device available: FAIL the skill. Do not skip.**
```

---

## Task 4: Remove/Simplify Redundant Skills

### Files to Modify

Since we simplified to smoke tests only, these skills may need adjustment:

**File:** `skills/android-sample-tests/SKILL.md`

**Action:** Either:
- Delete this skill entirely (smoke test is now in e2e-testing-setup), OR
- Keep it as an optional "add more tests" skill for users who want comprehensive tests later

**Recommendation:** Keep but rename to `android-additional-tests/SKILL.md` and make it clear it's optional, for adding tests beyond the smoke test.

---

## Task 5: Update Command Files

### Files to Modify

Update commands to reflect the simplified approach:

**File:** `commands/devtools/android-e2e-tests.md`

Update completion criteria:
```markdown
## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Espresso + UI Automator dependencies in `app/build.gradle.kts`
- [ ] `releaseTest` build type configured
- [ ] `SmokeTest.kt` exists in androidTest directory
- [ ] `./gradlew connectedDebugAndroidTest` passes
- [ ] Device/emulator was used (tests cannot run without one)
```

**File:** `commands/devtools/android-release-validate.md`

Update to emphasize device requirement:
```markdown
## ⚠️ Device Required

This command REQUIRES a connected device or running emulator.
It will FAIL if no device is available - validation cannot be skipped.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Device connected (`adb devices` shows device)
- [ ] `./gradlew connectedReleaseTestAndroidTest` passes
- [ ] ProGuard mapping file exists
- [ ] APK signature verified
```

---

## Task 6: Add Debugging Guide for Permission UI

### Files to Create

**File:** `skills/android-e2e-testing-setup/PERMISSION_DEBUGGING.md`

```markdown
# Debugging Permission UI with UI Automator

If the smoke test fails due to permission dialogs not being handled correctly,
use this guide to find the right UI selectors.

## Step 1: Capture UI Hierarchy

With the permission dialog showing on the device:

```bash
# Dump the UI hierarchy to a file
adb shell uiautomator dump /sdcard/ui_dump.xml

# Pull the file to your computer
adb pull /sdcard/ui_dump.xml

# View the XML
cat ui_dump.xml
```

## Step 2: Find Relevant Elements

Look for:
- `text` attributes containing "Allow", "Deny", "Health Connect", etc.
- `resource-id` attributes for buttons
- `class` attributes to understand element types

Example from HealthConnect:
```xml
<node resource-id="com.google.android.healthconnect:id/allow_button" 
      text="Allow" 
      class="android.widget.Button" />
```

## Step 3: Update SmokeTest.kt

Add selectors based on what you found:

```kotlin
// By resource ID (most reliable)
device.findObject(
    UiSelector().resourceId("com.google.android.healthconnect:id/allow_button")
)

// By text (works across versions)
device.findObject(
    UiSelector().text("Allow")
)

// By text pattern (handles variations)
device.findObject(
    UiSelector().textMatches("(?i)allow|permit")
)
```

## Step 4: Use UI Automator Viewer (Alternative)

If you have Android Studio:

```bash
$ANDROID_HOME/tools/bin/uiautomatorviewer
```

This provides a visual tool to inspect the UI hierarchy.

## Common HealthConnect Selectors

These may vary by Android version:

```kotlin
// Permission screen title
UiSelector().textContains("Health Connect")

// Allow all button
UiSelector().textMatches("(?i)allow all|select all")

// Individual permission toggle
UiSelector().className("android.widget.Switch")

// Confirm button
UiSelector().textMatches("(?i)allow|done|confirm|save")

// Cancel button (if you need to deny)
UiSelector().textMatches("(?i)cancel|deny|don't allow")
```
```

---

## Verification Checklist

After implementing all tasks, verify:

- [ ] `gradle.properties.template` is not created by any skill
- [ ] `SmokeTest.kt` uses `android.R.id.content` (no project-specific IDs)
- [ ] `SmokeTest.kt` includes UI Automator permission handling
- [ ] `releaseTest` build type is documented and configured
- [ ] E2E testing skill has hard device requirement
- [ ] Release validation skill has hard device requirement
- [ ] All commands reference updated completion criteria
- [ ] No skill mentions "skip if no device"

---

## Testing the Changes

After implementation, test with an Android project:

```bash
# 1. Run E2E testing setup
/devtools:android-e2e-tests

# Verify:
# - Dependencies added
# - SmokeTest.kt created with correct package
# - releaseTest build type added
# - Tests run and pass (requires device)

# 2. Run release validation
/devtools:android-release-validate

# Verify:
# - Requires device (fails if none)
# - Uses connectedReleaseTestAndroidTest
# - Tests pass on ProGuard build
```

---

## Summary of File Changes

| File | Action |
|------|--------|
| `skills/android-signing-config/SKILL.md` | Remove gradle.properties.template creation |
| `skills/android-e2e-testing-setup/SKILL.md` | Major rewrite - smoke test, UI Automator, releaseTest |
| `skills/android-release-validation/SKILL.md` | Add device requirement, use releaseTest |
| `skills/android-sample-tests/SKILL.md` | Optional: rename or delete |
| `commands/devtools/android-e2e-tests.md` | Update completion criteria |
| `commands/devtools/android-release-validate.md` | Add device requirement emphasis |
| `skills/android-e2e-testing-setup/PERMISSION_DEBUGGING.md` | Create new file |
