---
name: android-sample-tests
description: Generate sample Espresso tests for smoke testing and navigation
category: android
version: 1.0.0
inputs:
  - project_path: Path to Android project
  - package_name: App package name
  - main_activity: Main activity class name
outputs:
  - ExampleInstrumentedTest.kt (smoke tests)
  - MainActivityTest.kt (screen tests)
verify: "./gradlew connectedDebugAndroidTest"
---

# Android Sample Tests

Generates sample Espresso tests: smoke tests and main activity tests.

## Prerequisites

- Test structure created (run `android-test-structure` first)
- Package name and main activity known

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| project_path | Yes | . | Android project root |
| package_name | Yes | - | App package name |
| main_activity | Yes | MainActivity | Main activity class name |

## Process

### Step 1: Create Smoke Tests

Create `app/src/androidTest/kotlin/${PACKAGE_PATH}/ExampleInstrumentedTest.kt`:

```kotlin
package ${PACKAGE_NAME}

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.*

/**
 * Instrumented smoke tests - quick sanity checks
 */
@RunWith(AndroidJUnit4::class)
class ExampleInstrumentedTest {

    @Test
    fun appLaunches_correctPackage() {
        // Verify app package name
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals("${PACKAGE_NAME}", appContext.packageName)
    }

    @Test
    fun appContext_isNotNull() {
        // Verify app context is accessible
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        assertNotNull(appContext)
    }
}
```

### Step 2: Create Main Activity Tests

Create `app/src/androidTest/kotlin/${PACKAGE_PATH}/screens/MainActivityTest.kt`:

```kotlin
package ${PACKAGE_NAME}.screens

import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import ${PACKAGE_NAME}.${MAIN_ACTIVITY}
import ${PACKAGE_NAME}.base.BaseTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * E2E tests for ${MAIN_ACTIVITY}
 */
@RunWith(AndroidJUnit4::class)
class ${MAIN_ACTIVITY}Test : BaseTest() {

    @get:Rule
    val activityRule = ActivityScenarioRule(${MAIN_ACTIVITY}::class.java)

    @Test
    fun mainActivity_launches() {
        // Verify activity launches without crash
        activityRule.scenario.onActivity { activity ->
            assertNotNull(activity)
        }
    }

    @Test
    fun mainActivity_hasExpectedTitle() {
        // TODO: Add actual UI checks
        // Example:
        // onView(withId(R.id.toolbar_title))
        //     .check(matches(withText("App Title")))
        waitForIdle()
    }
}
```

### Step 3: Create GitHub Actions Workflow (Optional)

Create `.github/workflows/android-test.yml`:

```yaml
name: Android E2E Tests

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Setup Android SDK
        uses: android-actions/setup-android@v2

      - name: Run Espresso Tests
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 30
          target: google_apis
          arch: x86_64
          script: ./gradlew connectedDebugAndroidTest

      - name: Upload Test Reports
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-reports
          path: app/build/reports/androidTests/
```

## Verification

**MANDATORY:** Run tests (requires device or emulator):

```bash
# Start emulator or connect device first

# Run all tests
./gradlew connectedDebugAndroidTest

# View HTML report
open app/build/reports/androidTests/connected/index.html
```

**Expected output:**
- Tests execute successfully
- At least 2 tests pass
- HTML report generated

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| Smoke tests | ExampleInstrumentedTest.kt | Basic sanity checks |
| Screen tests | screens/MainActivityTest.kt | Main activity UI tests |
| CI workflow | .github/workflows/android-test.yml | GitHub Actions config |

## Troubleshooting

### "No tests found"
**Cause:** Package structure mismatch
**Fix:** Verify androidTest package matches main package

### "Activity not found"
**Cause:** Main activity name incorrect
**Fix:** Check actual activity class name in app/src/main/

### "Tests fail on emulator"
**Cause:** Animations interfering with tests
**Fix:** Disable animations in Developer Options

## Completion Criteria

- [ ] ExampleInstrumentedTest.kt exists with smoke tests
- [ ] MainActivityTest.kt exists with screen tests
- [ ] `./gradlew connectedDebugAndroidTest` executes
- [ ] At least one test passes
