---
name: android-e2e-testing-setup
description: Setup end-to-end testing for Android apps using Espresso (Google's official testing framework)
category: android
version: 1.0.0
---

# Android E2E Testing Setup

This skill configures comprehensive end-to-end testing for Android applications using Espresso, Google's official UI testing framework.

## What This Does

1. **Espresso Dependencies**
   - Adds androidx.test dependencies
   - Configures test runner
   - Sets up test orchestrator (optional, for isolation)
   - Adds Espresso core, intents, and contrib libraries

2. **Test Structure**
   - Creates androidTest source set
   - Generates package structure matching main app
   - Creates base test classes for reusability
   - Sets up test application class if needed

3. **Sample Tests**
   - Generates smoke test (app launches successfully)
   - Creates navigation test (basic screen transitions)
   - Adds interaction test (button clicks, text input)
   - Provides test utilities and helpers

4. **CI/CD Integration**
   - Configures tests for GitHub Actions
   - Sets up emulator for automated testing
   - Configures test reporting
   - Adds failure screenshot capture

## Prerequisites

- Android project with Gradle
- Kotlin or Java support
- Minimum SDK 21+ (Espresso requirement)
- Release build configuration (from android-release-build-setup)

## Parameters

None required - skill will detect project configuration and prompt for necessary information.

## Step-by-Step Process

### Step 1: Analyze Project Structure

Detect project configuration:

```kotlin
// Read app/build.gradle.kts to understand:
// - Package name / namespace
// - Minimum SDK version
// - Existing test dependencies
// - Existing test directory structure
```

**Ask the user:**
- "What is your main activity class name?" (for smoke test)
- "Do you want test orchestrator for better isolation?" (recommended for large test suites)
- "Should I create sample tests for your existing screens?" (if applicable)

### Step 2: Add Espresso Dependencies

Update `app/build.gradle.kts` with Espresso dependencies:

```kotlin
android {
    // ... existing config ...
    
    defaultConfig {
        // ... existing config ...
        
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        
        // Optional: Test orchestrator for better isolation
        // testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }
    
    // Optional: Test orchestrator configuration
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
        animationsDisabled = true  // Speeds up tests
        
        unitTests {
            isIncludeAndroidResources = true  // For Robolectric if needed
        }
    }
}

dependencies {
    // Existing dependencies...
    
    // Espresso core
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation("androidx.test.espresso:espresso-contrib:3.5.1")
    androidTestImplementation("androidx.test.espresso:espresso-intents:3.5.1")
    
    // AndroidX Test - Core and Runner
    androidTestImplementation("androidx.test:core:1.5.0")
    androidTestImplementation("androidx.test:core-ktx:1.5.0")
    androidTestImplementation("androidx.test:runner:1.5.2")
    androidTestImplementation("androidx.test:rules:1.5.0")
    
    // AndroidX Test - JUnit
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.ext:junit-ktx:1.1.5")
    
    // Kotlin Coroutines Test (if using coroutines)
    androidTestImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
    
    // Optional: Test orchestrator
    androidTestUtil("androidx.test:orchestrator:1.4.2")
    
    // Optional: Hamcrest matchers (more readable assertions)
    androidTestImplementation("org.hamcrest:hamcrest:2.2")
}
```

**Detection logic:**
- Check if dependencies already exist (don't duplicate)
- Check Kotlin vs Java (adjust imports accordingly)
- Check if using Jetpack Compose (add compose-testing if needed)
- Verify minimum SDK >= 21 (Espresso requirement)

### Step 3: Create Test Directory Structure

Create androidTest source set if it doesn't exist:

```
app/src/androidTest/
├── java/                          # For Java projects
│   └── com/example/app/           # Match package structure
│       ├── ExampleInstrumentedTest.kt
│       ├── base/
│       │   └── BaseTest.kt        # Reusable test base class
│       ├── screens/               # Screen-specific tests
│       │   ├── MainActivityTest.kt
│       │   └── LoginActivityTest.kt
│       └── utils/
│           ├── TestUtils.kt       # Test utilities
│           └── ScreenshotUtil.kt  # Failure screenshots
└── resources/                     # Test resources
    └── test-data.json             # Test data files
```

**For Kotlin projects:** Use `kotlin` directory instead of `java`

### Step 4: Create Base Test Class

Create `base/BaseTest.kt` for common test setup:

```kotlin
package com.example.app.base

import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import org.junit.After
import org.junit.Before
import org.junit.Rule

/**
 * Base class for all instrumented tests.
 * Provides common setup, teardown, and utilities.
 */
abstract class BaseTest {
    
    /**
     * Grants all dangerous permissions for testing.
     * Override in subclass if specific permissions needed.
     */
    @get:Rule
    val permissionRule: GrantPermissionRule = GrantPermissionRule.grant(
        android.Manifest.permission.CAMERA,
        android.Manifest.permission.ACCESS_FINE_LOCATION
    )
    
    /**
     * Application context for accessing resources.
     */
    protected val context by lazy {
        InstrumentationRegistry.getInstrumentation().targetContext
    }
    
    @Before
    open fun setUp() {
        // Common setup for all tests
        // Clear any existing app state
        clearAppData()
    }
    
    @After
    open fun tearDown() {
        // Common cleanup
        // Take screenshot on failure (handled by test runner)
    }
    
    /**
     * Clear app data before each test for isolation.
     */
    private fun clearAppData() {
        // Implementation depends on test requirements
        // Consider using test orchestrator instead for better isolation
    }
    
    /**
     * Wait for idle (animations complete, network calls done).
     */
    protected fun waitForIdle() {
        Espresso.onIdle()
    }
    
    /**
     * Custom wait with timeout.
     */
    protected fun wait(millis: Long = 1000) {
        Thread.sleep(millis)
    }
}
```

### Step 5: Create Smoke Test

Create `ExampleInstrumentedTest.kt` (smoke test):

```kotlin
package com.example.app

import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.*
import com.example.app.base.BaseTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented smoke test to verify app launches successfully.
 * 
 * This is the most basic E2E test - if the app can't launch,
 * all other tests will fail.
 */
@RunWith(AndroidJUnit4::class)
class ExampleInstrumentedTest : BaseTest() {
    
    @get:Rule
    val activityRule = ActivityScenarioRule(MainActivity::class.java)
    
    @Test
    fun appLaunches() {
        // Verify app package name is correct
        assertEquals("com.example.app", context.packageName)
    }
    
    @Test
    fun mainActivityDisplays() {
        // Verify main activity content is visible
        // Replace with actual view ID from your layout
        onView(withId(R.id.main_container))
            .check(matches(isDisplayed()))
    }
    
    @Test
    fun appDoesNotCrash() {
        // Simply launching the activity and waiting should not crash
        waitForIdle()
        // If we get here without crashing, test passes
    }
}
```

**Customization:**
- Replace `MainActivity` with actual main activity
- Replace `R.id.main_container` with actual view ID
- Ask user for main activity name during setup

### Step 6: Create Navigation Test

Create `screens/MainActivityTest.kt`:

```kotlin
package com.example.app.screens

import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.*
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.*
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.app.MainActivity
import com.example.app.R
import com.example.app.base.BaseTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Tests for MainActivity navigation and interactions.
 */
@RunWith(AndroidJUnit4::class)
class MainActivityTest : BaseTest() {
    
    @get:Rule
    val activityRule = ActivityScenarioRule(MainActivity::class.java)
    
    @Test
    fun clickButton_navigatesToNextScreen() {
        // Click a button (replace with actual button ID)
        onView(withId(R.id.button_next))
            .perform(click())
        
        // Verify navigation occurred (replace with actual verification)
        onView(withId(R.id.next_screen_title))
            .check(matches(isDisplayed()))
    }
    
    @Test
    fun enterText_displaysCorrectly() {
        // Type into an EditText
        onView(withId(R.id.edit_text_input))
            .perform(typeText("Test Input"), closeSoftKeyboard())
        
        // Verify text was entered
        onView(withId(R.id.edit_text_input))
            .check(matches(withText("Test Input")))
    }
    
    @Test
    fun scrollToItem_clicksItem() {
        // Scroll to an item in a RecyclerView/ListView
        onView(withId(R.id.recycler_view))
            .perform(scrollToPosition<RecyclerView.ViewHolder>(5))
        
        // Click the item
        onView(withText("Item 5"))
            .perform(click())
        
        // Verify action occurred
        waitForIdle()
    }
}
```

### Step 7: Create Test Utilities

Create `utils/TestUtils.kt`:

```kotlin
package com.example.app.utils

import android.view.View
import androidx.test.espresso.matcher.BoundedMatcher
import org.hamcrest.Description
import org.hamcrest.Matcher

/**
 * Utility functions for tests.
 */
object TestUtils {
    
    /**
     * Custom matcher to check if a view is at a specific position.
     */
    fun withPosition(position: Int): Matcher<View> {
        return object : BoundedMatcher<View, View>(View::class.java) {
            override fun describeTo(description: Description) {
                description.appendText("at position $position")
            }
            
            override fun matchesSafely(item: View): Boolean {
                val parent = item.parent
                if (parent is ViewGroup) {
                    return parent.indexOfChild(item) == position
                }
                return false
            }
        }
    }
    
    /**
     * Wait for a condition with timeout.
     */
    fun waitUntil(
        timeoutMillis: Long = 5000,
        condition: () -> Boolean
    ) {
        val startTime = System.currentTimeMillis()
        while (!condition()) {
            if (System.currentTimeMillis() - startTime > timeoutMillis) {
                throw TimeoutException("Condition not met within $timeoutMillis ms")
            }
            Thread.sleep(100)
        }
    }
    
    /**
     * Get string resource for testing.
     */
    fun getString(context: Context, @StringRes resId: Int): String {
        return context.getString(resId)
    }
}
```

Create `utils/ScreenshotUtil.kt`:

```kotlin
package com.example.app.utils

import android.graphics.Bitmap
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.screenshot.Screenshot
import java.io.File
import java.io.FileOutputStream

/**
 * Utility for capturing screenshots during test failures.
 */
object ScreenshotUtil {
    
    /**
     * Capture screenshot with given name.
     */
    fun capture(name: String) {
        val screenshot = Screenshot.capture()
        screenshot.name = name
        screenshot.format = Bitmap.CompressFormat.PNG
        
        // Process screenshot (save to file, upload, etc.)
        val processors = setOf(screenshot)
        screenshot.process(processors)
    }
    
    /**
     * Capture screenshot on test failure.
     * Call this in @After method or test watcher.
     */
    fun captureOnFailure(testName: String, hasFailed: Boolean) {
        if (hasFailed) {
            capture("failure_$testName")
        }
    }
}
```

### Step 8: Configure Test Runner for CI/CD

Create GitHub Actions workflow snippet for running tests:

```yaml
# Add to .github/workflows/android-test.yml

name: Android Tests

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main, develop ]

jobs:
  instrumented-tests:
    runs-on: macos-latest  # macOS for better emulator performance
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
          cache: 'gradle'
      
      - name: Grant execute permission for gradlew
        run: chmod +x gradlew
      
      - name: AVD cache
        uses: actions/cache@v4
        id: avd-cache
        with:
          path: |
            ~/.android/avd/*
            ~/.android/adb*
          key: avd-api-30
      
      - name: Create AVD and generate snapshot
        if: steps.avd-cache.outputs.cache-hit != 'true'
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 30
          target: google_apis
          arch: x86_64
          force-avd-creation: false
          emulator-options: -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none
          disable-animations: true
          script: echo "Generated AVD snapshot for caching."
      
      - name: Run instrumented tests
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 30
          target: google_apis
          arch: x86_64
          force-avd-creation: false
          emulator-options: -no-snapshot-save -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none
          disable-animations: true
          script: ./gradlew connectedDebugAndroidTest
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: app/build/reports/androidTests/
      
      - name: Upload test screenshots
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-screenshots
          path: app/build/outputs/androidTest-results/
```

### Step 9: Add Test Documentation

Create `androidTest/README.md`:

```markdown
# Android Instrumented Tests

This directory contains end-to-end tests for the Android app using Espresso.

## Running Tests

### Locally (Connected Device/Emulator)

```bash
# Run all tests
./gradlew connectedAndroidTest

# Run specific test class
./gradlew connectedAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.example.app.ExampleInstrumentedTest

# Run with test orchestrator (better isolation)
./gradlew connectedAndroidTest -Pandroid.testInstrumentationRunnerArguments.useTestOrchestrator=true
```

### In CI/CD

Tests run automatically on pull requests via GitHub Actions.
See `.github/workflows/android-test.yml` for configuration.

## Test Structure

- `base/` - Base test classes and common setup
- `screens/` - Screen-specific test classes
- `utils/` - Test utilities and helpers

## Writing Tests

### Smoke Tests
Verify basic functionality (app launches, screens display).
Should be fast and run on every commit.

### Navigation Tests
Verify screen transitions and navigation flows.

### Interaction Tests
Verify user interactions (clicks, typing, scrolling).

### Best Practices

1. **Fast Tests** - Keep tests under 5 seconds when possible
2. **Isolated Tests** - Don't depend on other tests
3. **Descriptive Names** - Use clear test method names
4. **Clean State** - Start each test with clean app state
5. **Wait Properly** - Use Espresso idling resources, not Thread.sleep()

## Troubleshooting

### "No tests found"
- Check package names match
- Verify test runner is configured
- Ensure test classes are in androidTest/

### "ViewMatchers not found"
- Check Espresso dependencies are added
- Sync Gradle files
- Invalidate caches and restart

### "Emulator tests fail locally but pass in CI"
- Check animations are disabled
- Verify emulator API level matches
- Check for race conditions

## Resources

- [Espresso Documentation](https://developer.android.com/training/testing/espresso)
- [Android Testing Guide](https://developer.android.com/training/testing)
- [Test Samples](https://github.com/android/testing-samples)
```

### Step 10: Verify Setup (MANDATORY)

**CRITICAL: This step is MANDATORY and must pass before completing the skill.**

Test the configuration with actual test execution:

```bash
# 1. Sync Gradle to download dependencies
./gradlew --refresh-dependencies

# 2. REQUIRED: Build test APK
./gradlew assembleDebugAndroidTest

# 3. REQUIRED: Verify test APK was created
ls -lh app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk

# 4. REQUIRED: Run tests on connected device/emulator
./gradlew connectedDebugAndroidTest

# 5. REQUIRED: Verify test reports generated
ls -lh app/build/reports/androidTests/connected/index.html

# 6. REQUIRED: Verify at least 1 test passed
grep -q "1 tests completed, 1 succeeded" app/build/reports/androidTests/connected/index.html || \
grep -q "test.*passed" app/build/reports/androidTests/connected/index.html
```

**Expected output:**
- Dependencies download: ✓ Success
- Test APK builds: ✓ app-debug-androidTest.apk exists
- Tests execute: ✓ At least 1 test runs
- Tests pass: ✓ At least 1 test succeeds
- HTML report exists: ✓ index.html generated

**If ANY of these checks fail:**
1. DO NOT mark the skill as complete
2. Investigate the error (check Gradle output)
3. Fix the issue (dependencies, test code, configuration)
4. Re-run all verification steps
5. Only complete when ALL checks pass

**Common Failures:**
- "No device/emulator" → Start emulator or connect device first
- "Test compilation fails" → Fix syntax errors in test files
- "Tests fail" → Expected for placeholder tests - replace with real tests
- "Dependencies not found" → Check internet, Maven repos, versions

### Step 11: Generate Summary Report

Provide comprehensive summary:

```
✅ Android E2E Testing Setup Complete!

📦 Dependencies Added:
  ✓ Espresso core, contrib, intents (v3.5.1)
  ✓ AndroidX Test runner and rules (v1.5.x)
  ✓ JUnit extensions for Android (v1.1.5)
  ✓ Test orchestrator (optional, v1.4.2)

🏗️  Test Structure Created:
  ✓ androidTest source set
  ✓ Base test class with common setup
  ✓ Test utilities and helpers
  ✓ Screenshot capture on failure

🧪 Sample Tests Generated:
  ✓ Smoke test (app launches)
  ✓ Navigation test (screen transitions)
  ✓ Interaction test (user input)
  ✓ Custom matchers and utilities

⚙️  Configuration:
  ✓ Test runner configured in build.gradle.kts
  ✓ Animations disabled for faster tests
  ✓ Test orchestrator enabled (optional)
  ✓ Android resources available in tests

🔄 CI/CD Integration:
  ✓ GitHub Actions workflow created
  ✓ Emulator configuration optimized
  ✓ Test result upload configured
  ✓ Screenshot upload on failure

📋 Next Steps:

  Run Tests Locally:
    1. Connect device or start emulator
    2. Run: ./gradlew connectedDebugAndroidTest
    3. View results: app/build/reports/androidTests/
  
  Customize Tests:
    1. Replace placeholder IDs with actual view IDs
    2. Add tests for your specific screens
    3. Configure test data and fixtures
    4. Add custom matchers as needed
  
  CI/CD Setup:
    1. Commit .github/workflows/android-test.yml
    2. Tests run automatically on PRs
    3. View results in GitHub Actions tab
  
  For Release Validation:
    1. Use android-release-validation skill
    2. Tests will run on release builds
    3. Validates ProGuard doesn't break functionality

⚠️  Important Notes:
  - Tests require real device or emulator (not unit tests)
  - Minimum SDK 21+ required for Espresso
  - Disable animations for reliable tests
  - Use test orchestrator for better isolation
  - Keep tests fast (< 5 seconds ideal)
```

## Error Handling

### Dependencies Not Downloading
- Check internet connection
- Clear Gradle cache: `./gradlew clean --refresh-dependencies`
- Check Maven repositories are accessible
- Verify versions are available

### Test Directory Not Created
- Check file permissions
- Verify source set configuration in build.gradle
- Create manually if needed: `mkdir -p app/src/androidTest/kotlin`

### Tests Not Running
- Verify device/emulator is connected: `adb devices`
- Check minimum SDK version >= 21
- Ensure test APK builds: `./gradlew assembleDebugAndroidTest`
- Check test runner configuration

### Espresso View Matching Fails
- Use Layout Inspector to find correct view IDs
- Add custom matchers for complex views
- Use `withText()`, `withContentDescription()` as alternatives
- Check for animations (should be disabled)

## Security Best Practices

1. **Test Data** - Don't use real user credentials in tests
2. **API Keys** - Use test API keys, not production
3. **Network** - Mock network calls or use test server
4. **Permissions** - Request only needed permissions
5. **Cleanup** - Clear sensitive data after tests

## Integration with Other Skills

This skill integrates with:
- `android-release-build-setup` - Tests validate release builds work with ProGuard
- `android-release-validation` - Uses these tests to validate release APK/AAB
- `android-playstore-pipeline` - Part of complete release workflow

## Troubleshooting

### "Failed to resolve: androidx.test.espresso"
Check repositories in build.gradle:
```kotlin
repositories {
    google()
    mavenCentral()
}
```

### "No tests were found"
- Verify package structure matches
- Check test runner configuration
- Ensure tests have @Test annotation
- Run with `--tests` flag for specific test

### "Emulator too slow"
- Use hardware acceleration (HAXM/KVM)
- Increase emulator RAM allocation
- Use x86_64 architecture (not ARM)
- Disable unnecessary emulator features

### "Tests pass locally but fail in CI"
- Check API levels match
- Disable animations in CI
- Use test orchestrator for isolation
- Check for race conditions

## Files Created/Modified

**Created:**
- `app/src/androidTest/kotlin/com/example/app/ExampleInstrumentedTest.kt`
- `app/src/androidTest/kotlin/com/example/app/base/BaseTest.kt`
- `app/src/androidTest/kotlin/com/example/app/screens/MainActivityTest.kt`
- `app/src/androidTest/kotlin/com/example/app/utils/TestUtils.kt`
- `app/src/androidTest/kotlin/com/example/app/utils/ScreenshotUtil.kt`
- `app/src/androidTest/README.md`
- `.github/workflows/android-test.yml`

**Modified:**
- `app/build.gradle.kts` - Added Espresso dependencies and test configuration

**Not Modified (Preserved):**
- Existing unit tests
- Existing dependencies
- Debug/release variants

## Completion Criteria (ALL MUST PASS)

Do NOT mark this skill as complete unless ALL of the following are verified:

✅ **Dependencies added**
  - [ ] Espresso dependencies in build.gradle.kts
  - [ ] Test runner configured (testInstrumentationRunner)
  - [ ] Test options configured (animations disabled)

✅ **Test structure created**
  - [ ] androidTest source set exists
  - [ ] base/BaseTest.kt created
  - [ ] ExampleInstrumentedTest.kt created
  - [ ] screens/MainActivityTest.kt created
  - [ ] utils/TestUtils.kt created
  - [ ] utils/ScreenshotUtil.kt created

✅ **MANDATORY: Test execution**
  - [ ] `./gradlew assembleDebugAndroidTest` succeeds
  - [ ] Test APK created: app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
  - [ ] `./gradlew connectedDebugAndroidTest` succeeds
  - [ ] At least 1 test executes successfully
  - [ ] Test report generated: app/build/reports/androidTests/connected/index.html

✅ **CI/CD configured**
  - [ ] .github/workflows/android-test.yml created
  - [ ] Workflow has emulator setup
  - [ ] Workflow runs connectedAndroidTest

✅ **Documentation created**
  - [ ] app/src/androidTest/README.md created
  - [ ] README contains running instructions

**If ANY checkbox is unchecked, the skill is NOT complete.**

## Expected Outcomes

After running this skill:

✅ **Can run E2E tests locally** - VERIFIED by connectedAndroidTest
✅ **CI/CD tests configured** - Workflow ready for GitHub Actions
✅ **Sample tests created** - VERIFIED by successful test execution
✅ **Test utilities available** - Custom matchers and helpers ready
✅ **Ready for release validation** - Tests can run on release builds

## Next Skills (Dependencies)

This skill DEPENDS on:
- `android-release-build-setup` - Must complete first (requires working build)

This skill is a PREREQUISITE for:
- `android-release-validation` - Uses these E2E tests on release builds
- `android-playstore-publishing` - Runs tests before deployment

Do NOT run this skill until `android-release-build-setup` completion criteria are met.
Do NOT run validation/publishing skills until this skill's completion criteria are met.

## References

- [Espresso Documentation](https://developer.android.com/training/testing/espresso)
- [Testing on Android](https://developer.android.com/training/testing)
- [AndroidX Test](https://developer.android.com/training/testing/set-up-project)
- [Test Samples](https://github.com/android/testing-samples)
- [UI Automator](https://developer.android.com/training/testing/other-components/ui-automator)
