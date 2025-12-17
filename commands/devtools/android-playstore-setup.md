---
description: Complete Play Store setup - orchestrates scanning, privacy policy, version management, and workflows (Internal track)
---

# Android Play Store Setup

Orchestrates complete Google Play Store deployment setup with automated publishing to the **internal testing track**.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-playstore-setup/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

**Project Files:**
- [ ] GPP plugin configured in `app/build.gradle.kts`
- [ ] Version scripts in `scripts/` directory
- [ ] Privacy policy in `docs/privacy-policy.md`
- [ ] Release notes in `src/main/play/release-notes/`
- [ ] Workflows: `.github/workflows/build.yml` and `release-internal.yml`

**GitHub Secrets:**
- [ ] `SERVICE_ACCOUNT_JSON_PLAINTEXT` configured
- [ ] `SIGNING_KEY_STORE_BASE64` configured
- [ ] `SIGNING_KEY_ALIAS` configured
- [ ] `SIGNING_STORE_PASSWORD` configured
- [ ] `SIGNING_KEY_PASSWORD` configured

**Play Console:**
- [ ] First manual upload completed
- [ ] Internal testing track active

## Quick Reference

**Inputs:** Google Play Developer account, package name, Play Console admin access
**Outputs:** Privacy policy, version scripts, signing config, GitHub workflows
**Verify:** `./gradlew assembleRelease && ./scripts/version-manager.sh latest`

## What This Orchestrates

1. **Scan Project** → `PLAY_CONSOLE_SETUP.md`
2. **Privacy Policy** → `docs/privacy-policy.md`
3. **Version Management** → `scripts/version-manager.sh`, `version.properties`
4. **Keystores** → `keystores/` directory
5. **Signing Config** → `app/build.gradle.kts`
6. **ProGuard** → `app/proguard-rules.pro`
7. **Workflows** → `build.yml` + `release-internal.yml`
8. **Service Account** → Setup guide
9. **API Validation** → `scripts/validate-playstore.py`

## Prerequisites

- Google Play Developer account ($25 one-time)
- Google Cloud Platform account (free)
- Admin access to Play Console
- Package name reserved in Play Console

## How to Release

After setup is complete:

1. Go to **Actions** → **Release to Internal Track**
2. Click **Run workflow**
3. Select version bump type (patch/minor/major)
4. Click **Run workflow**

## Related Commands

- `/devtools:android-playstore-scan` - Scan only (no modifications)
- `/devtools:privacy-policy` - Generate privacy policy only
- `/devtools:version-management` - Setup versioning only
- `/devtools:android-release-setup` - Signing and release build setup
- `/devtools:android-workflow-beta` - Add beta track workflow
- `/devtools:android-workflow-production` - Add production track workflow
