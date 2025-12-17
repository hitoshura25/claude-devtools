# Commands Update Spec

**Purpose:** Create command quick-links for new skills added in v4 spec
**Date:** 2025-12-14
**Status:** Ready for Implementation

---

## Overview

Commands in `/commands/devtools/` serve as quick-links that Claude Code can execute via `/devtools:<command-name>`. Each command file points to its corresponding skill and provides a quick reference.

**Pattern:** Command files are lightweight wrappers that:
1. Describe what the command does
2. Point to the skill file to execute
3. List completion criteria
4. Provide quick reference (inputs, outputs, verify)
5. List prerequisites and related commands

---

## Commands to Create

### 1. `version-management.md`

**File:** `commands/devtools/version-management.md`

```markdown
---
description: Setup technology-agnostic version management with Git tags as source of truth
---

# Version Management

Sets up semantic versioning using Git tags as the source of truth, with platform-specific adapters for fast builds.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/version-management/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] `scripts/version-manager.sh` exists and is executable
- [ ] Platform adapter exists (e.g., `scripts/gradle-version.sh`)
- [ ] Version file created (e.g., `version.properties` for Gradle)
- [ ] Build configuration reads from version file
- [ ] `./scripts/version-manager.sh latest` runs successfully

## Quick Reference

**Inputs:** Project path, platform (gradle/npm/python)
**Outputs:** Version scripts, version file, build config updates
**Verify:** `./scripts/version-manager.sh latest && ./scripts/version-manager.sh generate patch`

## Supported Platforms

| Platform | Adapter | Version File |
|----------|---------|--------------|
| Gradle/Android | `gradle-version.sh` | `version.properties` |
| npm (future) | `npm-version.sh` | `package.json` |
| Python (future) | `python-version.sh` | `__init__.py` |

## Related Commands

- `/devtools:android-playstore-setup` - Uses version management for releases
- `/devtools:android-release-setup` - Release build configuration
```

---

### 2. `privacy-policy.md`

**File:** `commands/devtools/privacy-policy.md`

```markdown
---
description: Generate privacy policy for apps with GitHub Pages hosting
---

# Privacy Policy Generator

Generates a comprehensive privacy policy by scanning your project, then creates a GitHub Pages-ready Markdown document.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/privacy-policy-generate/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] `docs/privacy-policy.md` exists with complete content
- [ ] `docs/PRIVACY_SETUP.md` exists with GitHub Pages instructions
- [ ] Privacy policy includes all detected features (Health Connect, ads, etc.)
- [ ] Developer name and contact email are correct
- [ ] Health data section included (if Health Connect detected)

## Quick Reference

**Inputs:** Project path, developer name, contact email
**Outputs:** `docs/privacy-policy.md`, `docs/PRIVACY_SETUP.md`
**Verify:** `test -f docs/privacy-policy.md && grep -q "Privacy Policy" docs/privacy-policy.md`

## Features Detected

- Health Connect integration and data types
- Third-party SDKs (Firebase, AdMob, etc.)
- Permissions (location, camera, etc.)
- Analytics and crash reporting

## After Generation

1. Enable GitHub Pages (Settings → Pages → Source: `/docs`)
2. Wait 1-2 minutes for deployment
3. Add URL to Play Console: `https://<username>.github.io/<repo>/privacy-policy`

## Related Commands

- `/devtools:android-playstore-scan` - Detects if privacy policy is needed
- `/devtools:android-playstore-setup` - Orchestrates full setup including privacy policy
```

---

### 3. `android-playstore-scan.md`

**File:** `commands/devtools/android-playstore-scan.md`

```markdown
---
description: Scan Android project and generate Play Console setup checklist (analysis only)
---

# Android Play Store Scanner

Analyzes your Android project and generates a comprehensive Play Console setup checklist. **Does NOT modify any files.**

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-playstore-scan/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] `PLAY_CONSOLE_SETUP.md` created in project root
- [ ] All project features detected correctly
- [ ] Privacy policy status identified
- [ ] Health Connect integration detected (if applicable)
- [ ] Action items clearly marked with checkboxes

## Quick Reference

**Inputs:** Project path (Android project with AndroidManifest.xml)
**Outputs:** `PLAY_CONSOLE_SETUP.md`
**Verify:** `test -f PLAY_CONSOLE_SETUP.md && grep -q "Play Console Setup Guide" PLAY_CONSOLE_SETUP.md`

## What It Detects

| Category | Detection |
|----------|-----------|
| App Info | Package name, app name |
| Permissions | Internet, location, camera, health |
| SDKs | Ads (AdMob), analytics (Firebase), payments |
| Health Connect | Data types, permissions |
| Privacy Policy | Existing policy URL or missing |

## Analysis Only

This command **only analyzes** your project. It does NOT:
- ❌ Create or modify any project files
- ❌ Setup GitHub Actions or workflows
- ❌ Generate privacy policies
- ❌ Configure signing or release builds

## Next Steps

After reviewing `PLAY_CONSOLE_SETUP.md`:

1. Address any action items (privacy policy, missing configs)
2. Run `/devtools:android-playstore-setup` to execute the actual setup

## Related Commands

- `/devtools:privacy-policy` - Generate privacy policy if missing
- `/devtools:android-playstore-setup` - Execute setup based on scan results
```

---

### 4. Update `android-playstore-setup.md`

**File:** `commands/devtools/android-playstore-setup.md`

**Action:** Replace existing content with updated v3.0.0 version

```markdown
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
- [ ] `SERVICE_ACCOUNT_JSON` configured
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
```

---

### 5. `android-ci-tests.md` (New)

**File:** `commands/devtools/android-ci-tests.md`

```markdown
---
description: Setup GitHub Actions CI workflow for Android tests (unit, lint, instrumented)
---

# Android CI Tests

Sets up GitHub Actions workflow for comprehensive Android testing including unit tests, lint checks, and instrumented tests with emulator.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-ci-tests/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] `.github/workflows/test.yml` exists and is valid YAML
- [ ] Unit tests job configured
- [ ] Lint job configured
- [ ] Instrumented tests job with emulator configured
- [ ] AVD caching enabled for faster emulator startup
- [ ] Test results uploaded as artifacts
- [ ] All actions pinned to commit SHAs

## Quick Reference

**Inputs:** Project path
**Outputs:** `.github/workflows/test.yml`
**Verify:** `yamllint .github/workflows/test.yml`

## Workflow Jobs

| Job | Purpose | Runs On |
|-----|---------|---------|
| `unit-tests` | Run `./gradlew test` | ubuntu-latest |
| `lint` | Run `./gradlew lint` | ubuntu-latest |
| `instrumented-tests` | Run on emulator | ubuntu-latest (KVM) |

## Emulator Configuration

- API Level: 34 (Android 14)
- Target: google_apis
- Arch: x86_64
- AVD caching enabled
- KVM acceleration

## Related Commands

- `/devtools:android-e2e-tests` - End-to-end testing setup
- `/devtools:android-playstore-setup` - Includes test job in release workflow
- `/devtools:test` - General test setup
```

---

## Implementation Checklist

- [ ] Create `commands/devtools/version-management.md`
- [ ] Create `commands/devtools/privacy-policy.md`
- [ ] Create `commands/devtools/android-playstore-scan.md`
- [ ] Create `commands/devtools/android-ci-tests.md`
- [ ] Update `commands/devtools/android-playstore-setup.md`

## Verification

After implementation, verify all commands are accessible:

```bash
# List all devtools commands
ls -la ~/claude-devtools/commands/devtools/

# Verify new commands exist
test -f ~/claude-devtools/commands/devtools/version-management.md && echo "✓ version-management"
test -f ~/claude-devtools/commands/devtools/privacy-policy.md && echo "✓ privacy-policy"
test -f ~/claude-devtools/commands/devtools/android-playstore-scan.md && echo "✓ android-playstore-scan"
test -f ~/claude-devtools/commands/devtools/android-ci-tests.md && echo "✓ android-ci-tests"

# Verify updated command
grep -q "v3.0.0\|orchestrates" ~/claude-devtools/commands/devtools/android-playstore-setup.md && echo "✓ android-playstore-setup updated"
```

## Command Usage

After implementation, these commands will be available:

```bash
/devtools:version-management      # Setup Git tag versioning
/devtools:privacy-policy          # Generate privacy policy
/devtools:android-playstore-scan  # Scan project (analysis only)
/devtools:android-ci-tests        # Setup CI test workflow
/devtools:android-playstore-setup # Full Play Store setup (orchestrator)
```
