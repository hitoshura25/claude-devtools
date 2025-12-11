---
description: Setup Espresso E2E testing for Android
---

# Android E2E Testing Setup

Configures Espresso testing framework with sample tests and CI integration.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-e2e-testing-setup/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Espresso dependencies in `app/build.gradle.kts`
- [ ] `app/src/androidTest/` directory exists with test files
- [ ] `./gradlew connectedDebugAndroidTest` executes (device required)
- [ ] At least one test passes

## Quick Reference

**Inputs:** Android project, release build working
**Outputs:** Espresso dependencies, test structure, sample tests
**Verify:** `./gradlew connectedDebugAndroidTest`

## Prerequisites

Run `/devtools:android-release-setup` first.

## Related Commands

- `/devtools:android-release-setup` - Required before this
- `/devtools:android-release-validate` - Run after this
