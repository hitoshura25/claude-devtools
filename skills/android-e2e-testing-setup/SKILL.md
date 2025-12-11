---
name: android-e2e-testing-setup
description: Complete E2E testing setup - orchestrates Espresso dependencies, test structure, and sample tests
category: android
version: 2.0.0
---

# Android E2E Testing Setup

This skill orchestrates complete Espresso E2E testing setup by running three atomic skills in sequence.

## What This Does

Sets up everything needed for Android E2E testing:
1. **Espresso Dependencies** - Test framework libraries
2. **Test Structure** - Directory structure and base classes
3. **Sample Tests** - Working test examples to start from

## Prerequisites

- Android project with Gradle
- Release build configured (run `android-release-build-setup` first)
- Minimum SDK 21+ (Espresso requirement)
- Device or emulator for running tests

## Process

This skill runs three sub-skills in order:

### Step 1: Add Espresso Dependencies

Follow the skill at: `~/claude-devtools/skills/android-espresso-dependencies/SKILL.md`

**What it does:**
- Adds Espresso core, contrib, intents dependencies
- Adds AndroidX Test runner and rules
- Configures test orchestrator (optional)

**Verify before continuing:**
```bash
./gradlew dependencies | grep espresso
```

---

### Step 2: Create Test Structure

Follow the skill at: `~/claude-devtools/skills/android-test-structure/SKILL.md`

**What it does:**
- Creates androidTest directory structure
- Creates BaseTest.kt with common utilities
- Creates TestUtils.kt with helper functions
- Creates README for test documentation

**Verify before continuing:**
```bash
test -d app/src/androidTest
ls app/src/androidTest/kotlin/*/base/BaseTest.kt
```

---

### Step 3: Generate Sample Tests

Follow the skill at: `~/claude-devtools/skills/android-sample-tests/SKILL.md`

**What it does:**
- Creates smoke tests (ExampleInstrumentedTest.kt)
- Creates main activity tests
- Optionally creates GitHub Actions workflow

**Verify before continuing:**
```bash
./gradlew connectedDebugAndroidTest
```

---

## Final Verification (MANDATORY)

After all three skills complete, verify the complete setup:

```bash
# 1. Verify test structure
test -d app/src/androidTest/kotlin && echo "✓ Test structure exists"

# 2. Run all tests
./gradlew connectedDebugAndroidTest

# 3. Check test report
ls app/build/reports/androidTests/connected/index.html && echo "✓ Test report generated"
```

**All checks must pass** before marking this skill as complete.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

✅ **Dependencies added**
  - [ ] Espresso dependencies in app/build.gradle.kts
  - [ ] AndroidX Test dependencies added
  - [ ] Test runner configured

✅ **Test structure created**
  - [ ] app/src/androidTest/ directory exists
  - [ ] BaseTest.kt exists
  - [ ] TestUtils.kt exists

✅ **Sample tests created**
  - [ ] ExampleInstrumentedTest.kt exists
  - [ ] MainActivityTest.kt exists

✅ **MANDATORY: Tests run**
  - [ ] `./gradlew connectedDebugAndroidTest` executes
  - [ ] At least one test passes
  - [ ] Test report generated

## Summary Report

After completion, provide this summary:

```
✅ Android E2E Testing Setup Complete!

📦 Dependencies Added:
  ✓ Espresso core, contrib, intents
  ✓ AndroidX Test runner and rules
  ✓ Test orchestrator configured

📁 Test Structure Created:
  ✓ androidTest directory: app/src/androidTest/
  ✓ Base class: BaseTest.kt
  ✓ Utilities: TestUtils.kt
  ✓ Documentation: README.md

✅ Sample Tests Generated:
  ✓ Smoke tests: ExampleInstrumentedTest.kt
  ✓ Screen tests: MainActivityTest.kt

📋 Next Steps:

  Run Tests:
    ./gradlew connectedDebugAndroidTest

  View Report:
    open app/build/reports/androidTests/connected/index.html

  Customize Tests:
    1. Replace placeholder view IDs with actual IDs
    2. Add tests for specific screens and flows
    3. Add custom matchers in TestUtils

⚠️  Test Best Practices:
  - Keep tests fast (< 5 seconds each)
  - Test user flows, not implementation details
  - Use descriptive test names
  - Isolate tests (no dependencies between tests)
```

## Integration with Other Skills

This skill is prerequisite for:
- `android-release-validation` - Runs E2E tests on release builds
- `android-playstore-pipeline` - Validates builds before deployment

## Troubleshooting

If any skill fails:
1. Fix the specific issue in that skill
2. Re-run that skill until it completes
3. Continue with remaining skills
4. Run final verification

Common issues:
- **No device found** → Start emulator or connect device
- **Tests fail** → Check view IDs match actual layouts
- **Animations interfere** → Disable animations in emulator
