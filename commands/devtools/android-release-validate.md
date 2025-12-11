---
description: Validate Android release builds to ensure quality and catch ProGuard issues before deployment
---

# Android Release Validation

Validates release builds before publishing to catch ProGuard issues and ensure production readiness.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-release-validation/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] `./gradlew assembleRelease` succeeds
- [ ] `./gradlew connectedReleaseAndroidTest` passes
- [ ] ProGuard mapping file exists: `app/build/outputs/mapping/release/mapping.txt`
- [ ] `jarsigner -verify` confirms APK is signed
- [ ] All E2E tests pass on release build (no ProGuard breakage)

## Quick Reference

**Inputs:** Android project with release build and E2E tests configured
**Outputs:** Validated release APK/AAB, ProGuard mapping, validation report
**Verify:** `./gradlew connectedReleaseAndroidTest`

## Prerequisites

- Run `/devtools:android-release-setup` first
- Run `/devtools:android-e2e-tests` first
- Device or emulator connected

## Related Commands

- `/devtools:android-release-setup` - Required before this
- `/devtools:android-e2e-tests` - Required before this
- `/devtools:android-playstore-publish` - Run after validation passes
