---
description: Validate Android release builds to ensure quality and catch ProGuard issues before deployment
---

# Android Release Validation

Validates release builds before publishing to catch ProGuard issues and ensure production readiness.

## ⚠️ Device Required

This command REQUIRES a connected device or running emulator.
It will FAIL if no device is available - validation cannot be skipped.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-release-validation/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Device connected (`adb devices` shows device)
- [ ] Release APK built and signed
- [ ] `apksigner verify` confirms valid signature
- [ ] Release APK installed on device
- [ ] Smoke tests pass against release APK (via `adb shell am instrument`)
- [ ] ProGuard mapping file exists

## Quick Reference

**Inputs:** Android project with release build and E2E tests configured
**Outputs:** Validated release APK/AAB, ProGuard mapping, validation report
**Verify:** `adb shell am instrument` with release APK

## Prerequisites

- Run `/devtools:android-release-setup` first
- Run `/devtools:android-e2e-tests` first
- Device or emulator connected

## Related Commands

- `/devtools:android-release-setup` - Required before this
- `/devtools:android-e2e-tests` - Required before this
- `/devtools:android-playstore-publish` - Run after validation passes
