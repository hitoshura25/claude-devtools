---
description: Setup UI Automator 2.4 E2E testing for Android
---

# Android E2E Testing Setup

Configures UI Automator 2.4 testing framework with modern API and smoke tests.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-e2e-testing-setup/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] UI Automator 2.4 dependency in `app/build.gradle.kts`
- [ ] `SmokeTest.kt` exists using modern `uiAutomator { }` API
- [ ] `./gradlew connectedDebugAndroidTest` passes
- [ ] Device/emulator was used (tests cannot run without one)
- [ ] HealthConnect permissions handled automatically by test

## Quick Reference

**Inputs:** Android project
**Outputs:** UI Automator 2.4 dependencies, SmokeTest.kt with modern API
**Verify:** `./gradlew connectedDebugAndroidTest`

## Prerequisites

Run `/devtools:android-release-setup` first.

## Related Commands

- `/devtools:android-release-setup` - Required before this
- `/devtools:android-release-validate` - Run after this
