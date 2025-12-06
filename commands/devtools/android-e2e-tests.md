---
description: Setup end-to-end testing for Android apps using Espresso (Google's official UI testing framework)
---

# Android E2E Testing Setup

Configure comprehensive end-to-end testing for Android applications using Espresso, Google's official and recommended UI testing framework.

## What This Command Does

Sets up complete E2E testing infrastructure:
- ✅ Espresso dependencies (core, contrib, intents)
- ✅ AndroidX Test libraries (runner, rules, JUnit extensions)
- ✅ Test directory structure with base classes
- ✅ Sample smoke, navigation, and interaction tests
- ✅ Test utilities and screenshot capture
- ✅ GitHub Actions CI/CD configuration

## Usage

```bash
/devtools:android-e2e-tests
```

## Interactive Setup

The command will:
1. Analyze your Android project structure
2. Ask for your main activity class name
3. Ask about test orchestrator (recommended for large test suites)
4. Add Espresso dependencies to build.gradle.kts
5. Create androidTest directory structure
6. Generate base test class with common utilities
7. Create sample tests (smoke, navigation, interaction)
8. Add test utilities (custom matchers, screenshot capture)
9. Create GitHub Actions workflow for CI/CD
10. Provide setup summary and next steps

## What Gets Created

**Dependencies Added:**
- `androidx.test.espresso:espresso-core` - Core Espresso library
- `androidx.test.espresso:espresso-contrib` - Additional Espresso utilities
- `androidx.test.espresso:espresso-intents` - Intent verification
- `androidx.test:runner` - Test runner
- `androidx.test.ext:junit` - JUnit integration
- `androidx.test:orchestrator` - Test isolation (optional)

**Test Classes Created:**
- `app/src/androidTest/.../base/BaseTest.kt` - Common test setup
- `app/src/androidTest/.../ExampleInstrumentedTest.kt` - Smoke tests
- `app/src/androidTest/.../screens/MainActivityTest.kt` - Screen tests
- `app/src/androidTest/.../utils/TestUtils.kt` - Test helpers
- `app/src/androidTest/.../utils/ScreenshotUtil.kt` - Screenshot capture

**Configuration Files:**
- Updated `app/build.gradle.kts` - Test dependencies and runner config
- `.github/workflows/android-test.yml` - CI/CD workflow
- `app/src/androidTest/README.md` - Testing documentation

## Prerequisites

- Android project with Gradle wrapper
- Minimum SDK 21+ (Espresso requirement)
- Kotlin or Java project
- Android device or emulator for running tests

## After Running This Command

**Run Tests Locally:**
```bash
# Start emulator or connect device
./gradlew connectedDebugAndroidTest

# View HTML report
open app/build/reports/androidTests/connected/index.html
```

**Customize Tests:**
1. Replace placeholder view IDs with actual IDs from your layouts
2. Add tests for your specific screens and user flows
3. Configure test data and fixtures
4. Add custom matchers for complex UI elements

**CI/CD:**
Tests will automatically run on pull requests to main/develop branches.
Results and screenshots available as GitHub Actions artifacts.

## Test Types Included

### 1. Smoke Tests
**Purpose:** Verify app launches and basic structure
**Speed:** Fast (< 10 seconds)
**When:** Every commit

```kotlin
@Test
fun appLaunches_correctPackage() {
    assertEquals("com.example.app", context.packageName)
}
```

### 2. Navigation Tests
**Purpose:** Verify screen transitions work correctly
**Speed:** Medium (< 30 seconds)
**When:** Before merging to main

```kotlin
@Test
fun clickButton_navigatesToNextScreen() {
    onView(withId(R.id.button_next)).perform(click())
    onView(withId(R.id.next_screen)).check(matches(isDisplayed()))
}
```

### 3. Interaction Tests
**Purpose:** Verify user inputs and form validation
**Speed:** Medium (< 30 seconds)
**When:** Before merging to main

```kotlin
@Test
fun enterText_displaysCorrectly() {
    onView(withId(R.id.input)).perform(typeText("Test"))
    onView(withId(R.id.input)).check(matches(withText("Test")))
}
```

## Features

**Base Test Class:**
- Common setup/teardown logic
- Permission management
- Context access
- Wait utilities

**Test Utilities:**
- Custom view matchers
- Conditional waiting with timeout
- RecyclerView position matchers
- String resource helpers

**Screenshot Capture:**
- Automatic screenshots on failure
- Before/after action screenshots
- Stored as CI/CD artifacts

**CI/CD Integration:**
- Optimized emulator caching
- Parallel test execution
- Test result publishing
- Screenshot upload on failure

## Configuration Options

### Test Orchestrator (Recommended)
Better test isolation, each test runs in separate process:

```kotlin
// In build.gradle.kts
testOptions {
    execution = "ANDROIDX_TEST_ORCHESTRATOR"
}
```

### Animation Disabling (Recommended)
Faster and more reliable tests:

```kotlin
testOptions {
    animationsDisabled = true
}
```

### Test Data Management
Create test fixtures in `androidTest/resources/`

## Integration with Other Skills

### Prerequisites:
- `android-release-build-setup` - Creates release builds that tests can validate

### Used By:
- `android-release-validation` - Runs these tests on release builds
- `android-playstore-pipeline` - Validates builds before deployment

## Common Use Cases

**1. Validate New Features:**
```bash
# Add feature implementation
# Run E2E tests to verify it works
./gradlew connectedAndroidTest
```

**2. Catch Regressions:**
```bash
# Make changes to existing code
# Tests catch broken functionality
./gradlew connectedAndroidTest
```

**3. Validate Release Builds:**
```bash
# Build release APK
# Run E2E tests to ensure ProGuard didn't break anything
./gradlew connectedReleaseAndroidTest
```

## Troubleshooting

**"No tests found"**
→ Check package structure matches between main and androidTest
→ Verify @Test annotations are present

**"Emulator tests fail"**
→ Disable animations: Settings → Developer Options → Animation Scale → Off
→ Use API level 30+ for better reliability

**"Tests are flaky"**
→ Enable test orchestrator for better isolation
→ Use `waitForIdle()` instead of `Thread.sleep()`
→ Add proper wait conditions for async operations

## Best Practices

1. **Keep tests fast** - Under 5 seconds per test ideal
2. **Test user flows** - Not implementation details
3. **Use descriptive names** - Clearly state what's being tested
4. **Isolate tests** - No dependencies between tests
5. **Clean state** - Start fresh for each test

## Skill Reference

This command uses the skill at:
`~/.claude/skills/user/devtools/android-e2e-testing-setup/SKILL.md`

For detailed implementation steps, troubleshooting, and technical details, refer to the skill documentation.

## Related Commands

- `/devtools:android-release-setup` - Setup release builds (prerequisite)
- `/devtools:android-release-validate` - Validate release with E2E tests
- `/devtools:android-playstore-pipeline` - Complete deployment pipeline

## Example Session

```
User: /devtools:android-e2e-tests

Claude: I'll set up Espresso testing for your Android app. Let me analyze your project.

Detected:
- Project: ~/my-android-app
- Package: com.example.myapp
- Main Activity: MainActivity
- Min SDK: 26 ✓ (Espresso requires 21+)

What is your main activity class name (for smoke tests)?
→ MainActivity

Do you want to enable test orchestrator for better isolation?
(Recommended for large test suites, slightly slower)
→ Yes

Adding dependencies...
✓ Espresso core, contrib, intents
✓ AndroidX Test runner and rules
✓ Test orchestrator

Creating test structure...
✓ androidTest directory created
✓ BaseTest.kt with common utilities
✓ ExampleInstrumentedTest.kt (smoke tests)
✓ MainActivityTest.kt (screen tests)
✓ TestUtils.kt and ScreenshotUtil.kt

Configuring CI/CD...
✓ GitHub Actions workflow created
✓ Emulator caching configured

Setup complete!

Run tests:
  ./gradlew connectedDebugAndroidTest

Next: Customize tests by replacing placeholder view IDs
```

## Notes

- Tests require real device or emulator (cannot run on JVM)
- API level 21+ required for Espresso
- macOS recommended for faster CI emulator performance
- Test execution time depends on device/emulator speed
- Screenshot capture requires storage permissions

## Version Information

- **Espresso:** 3.5.1 (latest stable)
- **AndroidX Test:** 1.5.x
- **Test Orchestrator:** 1.4.2
- **Minimum Android SDK:** 21 (Android 5.0 Lollipop)
