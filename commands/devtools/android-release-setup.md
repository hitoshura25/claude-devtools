---
description: Setup Android release build configuration with keystores, ProGuard, and signing
---

# Android Release Build Setup

Configures complete release build for Android: dual keystores, ProGuard/R8, and signing configuration.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-release-build-setup/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly as documented.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] `./gradlew assembleRelease` succeeds
- [ ] APK exists: `app/build/outputs/apk/release/app-release.apk`
- [ ] Mapping exists: `app/build/outputs/mapping/release/mapping.txt`
- [ ] Keystores created in `keystores/` directory
- [ ] `keystores/` is in `.gitignore`
- [ ] `apksigner verify` confirms APK is signed (v2/v3 schemes)

## Quick Reference

**Inputs:** Android project with Gradle, JDK installed
**Outputs:** Keystores, ProGuard config, signing setup, build.gradle.kts updates
**Verify:** `./gradlew assembleRelease && ls app/build/outputs/apk/release/`

## Related Commands

- `/devtools:android-e2e-tests` - Setup testing (run after this)
- `/devtools:android-release-validate` - Validate release builds
- `/devtools:android-playstore-pipeline` - Complete pipeline setup
