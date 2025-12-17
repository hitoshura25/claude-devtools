# Skills Refactoring Implementation Spec

## Overview

This document specifies changes to the `claude-devtools` skills and commands based on empirical reliability analysis. The goal is to create a cleaner architecture where:

1. **Commands** are thin pass-throughs that reference skills
2. **Skills** are focused, single-purpose units (not orchestrators)
3. **MCP tools** handle orchestration of multiple skills

## Problem Statement

### Current Issues Identified

1. **Command/Skill Duplication:** Commands duplicate skill content, creating maintenance burden and potential drift
2. **Skills Try to Orchestrate:** Multi-step skills have 40-60% reliability because agents skip steps
3. **Inconsistent Execution:** Same skill produces different results across runs due to probabilistic agent behavior

### Root Cause Analysis

```
Agent Decision Points × Steps = Failure Probability

Single-step skill:  1 decision  → ~95% success
5-step skill:       5 decisions → ~60% success (0.95^5 ≈ 0.77, but with attention drift ~60%)
10-step skill:      10 decisions → ~40% success
```

### Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Request                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Command (Pass-through)                    │
│  - Points to skill                                          │
│  - Lists completion criteria                                │
│  - No implementation details                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Skill (Single-Purpose)                    │
│  - One focused action                                       │
│  - Clear inputs/outputs                                     │
│  - Verification command                                     │
│  - No orchestration of other skills                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              MCP Tool (Orchestration - Future)               │
│  - Combines multiple skills                                 │
│  - Deterministic execution                                  │
│  - Progress reporting                                       │
│  - 95% reliability                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 1: Command Refactoring

### Principle

Commands should be **thin pass-throughs** that:
- Reference the skill file location
- State what the skill does (1-2 sentences)
- List completion criteria (checkboxes)
- Provide NO implementation details

### Template for Pass-Through Commands

```markdown
---
description: [One-line description]
---

# [Command Name]

[1-2 sentence summary of what this does]

## Skill Reference

**Read and execute the skill at:**
`/path/to/skill/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] [Criterion 1 - specific, verifiable]
- [ ] [Criterion 2 - specific, verifiable]
- [ ] [Criterion 3 - specific, verifiable]

## Quick Reference

**Inputs:** [What the skill needs]
**Outputs:** [What gets created]
**Verify:** `[single command to verify success]`

## Related Commands

- `/command1` - [relationship]
- `/command2` - [relationship]
```

### Commands to Refactor

| Command | Current State | Action |
|---------|---------------|--------|
| `devtools/android-release-setup.md` | Verbose, duplicates skill | Refactor to pass-through |
| `devtools/android-e2e-tests.md` | Verbose, duplicates skill | Refactor to pass-through |
| `devtools/android-release-validate.md` | Verbose, duplicates skill | Refactor to pass-through |
| `devtools/android-playstore-setup.md` | Verbose, duplicates skill | Refactor to pass-through |
| `devtools/android-playstore-publish.md` | Verbose, duplicates skill | Refactor to pass-through |
| `devtools/android-playstore-pipeline.md` | Orchestrator command | **Special case - see Part 3** |
| `devtools/develop.md` | Check if duplicates | Refactor if needed |
| `devtools/lint.md` | Check if duplicates | Refactor if needed |
| `devtools/security.md` | Check if duplicates | Refactor if needed |
| `devtools/setup-npm.md` | Check if duplicates | Refactor if needed |
| `devtools/setup-pypi.md` | Check if duplicates | Refactor if needed |
| `devtools/spec.md` | Check if duplicates | Refactor if needed |
| `devtools/test.md` | Check if duplicates | Refactor if needed |
| `devtools/validate.md` | Check if duplicates | Refactor if needed |

### Example: Refactored android-release-setup.md

**Before (verbose):** ~150 lines duplicating skill content

**After (pass-through):**

```markdown
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
- [ ] `jarsigner -verify` confirms APK is signed

## Quick Reference

**Inputs:** Android project with Gradle, JDK installed
**Outputs:** Keystores, ProGuard config, signing setup, build.gradle.kts updates
**Verify:** `./gradlew assembleRelease && ls app/build/outputs/apk/release/`

## Related Commands

- `/devtools:android-e2e-tests` - Setup testing (run after this)
- `/devtools:android-release-validate` - Validate release builds
- `/devtools:android-playstore-pipeline` - Complete pipeline setup
```

---

## Part 2: Skill Decomposition

### Principle

Skills should be **single-purpose** and focus on ONE action. If a skill has multiple distinct phases, split it.

### Analysis: Current Android Skills

| Skill | Current Scope | Recommendation |
|-------|---------------|----------------|
| `android-release-build-setup` | Keystores + ProGuard + Signing + Validation | **Split into 3-4 skills** |
| `android-e2e-testing-setup` | Dependencies + Structure + Sample Tests + CI | **Split into 2-3 skills** |
| `android-release-validation` | Build + Test + Sign Check + Analyze | Keep (validation is inherently multi-check) |
| `android-playstore-setup` | Service Account + API + Release Notes | **Split into 2-3 skills** |
| `android-playstore-publishing` | 4 Workflows + Scripts | **Split into 2-3 skills** |
| `android-playstore-pipeline` | Orchestrates 5 skills | **Remove as skill, implement as MCP tool** |

### Proposed Skill Decomposition

#### From `android-release-build-setup`:

1. **`android-keystore-generation`** (NEW)
   - Generates production and local dev keystores
   - Creates KEYSTORE_INFO.txt
   - Updates .gitignore
   - **Verify:** Keystores exist, passwords documented

2. **`android-proguard-setup`** (NEW)
   - Creates proguard-rules.pro with safe defaults
   - Enables minification in build.gradle.kts
   - Enables resource shrinking
   - **Verify:** `isMinifyEnabled = true` in build config

3. **`android-signing-config`** (NEW)
   - Adds signingConfigs to build.gradle.kts
   - Configures release buildType
   - Sets up dual-source (env vars + gradle.properties)
   - **Verify:** `./gradlew assembleRelease` succeeds

4. **`android-release-build-setup`** (REFACTORED)
   - Becomes a **reference document** listing the 3 skills above
   - Or becomes a thin orchestrator that calls the 3 skills
   - Eventually replaced by MCP tool

#### From `android-e2e-testing-setup`:

1. **`android-espresso-dependencies`** (NEW)
   - Adds Espresso dependencies to build.gradle.kts
   - Configures test runner
   - **Verify:** `./gradlew dependencies | grep espresso`

2. **`android-test-structure`** (NEW)
   - Creates androidTest directory structure
   - Creates BaseTest.kt and utilities
   - **Verify:** Directory structure exists

3. **`android-sample-tests`** (NEW)
   - Generates smoke test
   - Generates navigation test
   - **Verify:** `./gradlew connectedDebugAndroidTest` runs

#### From `android-playstore-setup`:

1. **`android-service-account-guide`** (NEW)
   - Step-by-step guide for Google Cloud service account
   - No automated actions (pure documentation)
   - **Verify:** User confirms service account created

2. **`android-release-notes-structure`** (NEW)
   - Creates distribution/whatsnew directory
   - Creates locale folders and templates
   - **Verify:** Directory structure exists

3. **`android-playstore-api-validation`** (NEW)
   - Creates validation script
   - Tests API connection
   - **Verify:** Script runs successfully

#### From `android-playstore-publishing`:

1. **`android-workflow-internal`** (NEW)
   - Creates deploy-internal.yml
   - **Verify:** YAML valid, package name correct

2. **`android-workflow-production`** (NEW)
   - Creates deploy-production.yml and manage-rollout.yml
   - **Verify:** YAML valid, environment configured

3. **`android-workflow-beta`** (NEW)
   - Creates deploy-beta.yml
   - **Verify:** YAML valid

### Skill Template (Single-Purpose)

```markdown
---
name: [skill-name]
description: [One sentence - what this single action does]
category: [category]
version: 1.0.0
inputs:
  - [input 1]
  - [input 2]
outputs:
  - [output 1]
  - [output 2]
verify: "[single command to verify success]"
---

# [Skill Name]

[One paragraph describing what this skill does - single action only]

## Prerequisites

- [Prerequisite 1]
- [Prerequisite 2]

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| project_path | Yes | Path to Android project |
| ... | ... | ... |

## Process

### Step 1: [Action]

[Detailed instructions for this step]

```bash
# Commands to execute
```

### Step 2: [Action] (if needed)

[Keep to 2-3 steps maximum for single-purpose skill]

## Verification

**MANDATORY:** Run this command to verify success:

```bash
[single verification command]
```

**Expected output:** [What success looks like]

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| [file] | [path] | [description] |

## Troubleshooting

### [Common Error 1]
**Cause:** [Why this happens]
**Fix:** [How to fix]

## Completion Criteria

- [ ] [Specific verifiable criterion]
- [ ] [Specific verifiable criterion]
```

---

## Part 3: Orchestration Commands

### Problem

The `android-playstore-pipeline` command/skill tries to orchestrate 5 other skills. This is exactly where reliability drops to 40-60%.

### Solution Options

#### Option A: Remove Orchestration Commands (Recommended for Now)

Delete orchestration commands. Users run individual skills in order, guided by documentation.

**Pros:**
- Simple
- No false promises of reliability
- Each skill runs at ~95% reliability

**Cons:**
- User must remember order
- More manual work

#### Option B: Document-Only Orchestration

Keep command but make it documentation only:

```markdown
---
description: Complete Android Play Store pipeline (manual orchestration)
---

# Android Play Store Pipeline

This command guides you through setting up a complete deployment pipeline.

## ⚠️ Important: Manual Orchestration Required

Due to reliability constraints, run each skill individually in order.
Future: MCP tool will automate this with 95% reliability.

## Execution Order

Run these commands in sequence, verifying each before proceeding:

### 1. Release Build Setup
```
/devtools:android-release-setup
```
**Verify before continuing:** `./gradlew assembleRelease` succeeds

### 2. E2E Testing
```
/devtools:android-e2e-tests
```
**Verify before continuing:** `./gradlew connectedDebugAndroidTest` succeeds

### 3. Release Validation
```
/devtools:android-release-validate
```
**Verify before continuing:** `./gradlew connectedReleaseAndroidTest` succeeds

### 4. Play Store Setup
```
/devtools:android-playstore-setup
```
**Verify before continuing:** API validation script passes

### 5. Publishing Workflows
```
/devtools:android-playstore-publish
```
**Verify before continuing:** All workflow YAML files valid

## Future: MCP Tool Orchestration

When `@hitoshura25/mcp-android` is available, use:
```
mcp__android__setup_playstore_pipeline
```
This will execute all steps with 95% reliability.
```

#### Option C: MCP Tool (Future)

Implement orchestration in MCP tool. This is the long-term solution.

### Recommended Approach

1. **Immediate:** Convert to document-only orchestration (Option B)
2. **Future:** Implement MCP tool for orchestration (Option C)
3. **Eventually:** Remove document-only command when MCP tool is proven

---

## Part 4: Skill Bug Fixes

### Issue: PKCS12 Keystore Password

**Location:** `skills/android-release-build-setup/SKILL.md`

**Problem:** Skill implies storepass and keypass can differ, but PKCS12 (JDK 9+ default) requires them to be identical.

**Fix:**

Find:
```bash
keytool -genkeypair -v \
  -keystore production-release.jks \
  -alias upload \
  ...
  -storepass [GENERATED_SECURE_PASSWORD] \
  -keypass [GENERATED_SECURE_PASSWORD] \
```

Replace with:
```bash
# Generate a single secure password (PKCS12 requires same password for store and key)
# Using openssl for secure random generation
PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)

keytool -genkeypair -v \
  -keystore production-release.jks \
  -storetype PKCS12 \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$PASSWORD" \
  -keypass "$PASSWORD" \
  -dname "CN=Android Release, OU=Release, O=[COMPANY], L=[CITY], ST=[STATE], C=[COUNTRY]"

# IMPORTANT: PKCS12 format requires storepass and keypass to be identical.
# This is enforced by using the same $PASSWORD variable for both.
```

Also update KEYSTORE_INFO.txt template:
```
Store Password: [PASSWORD]
Key Password: [PASSWORD]  # Same as store password (PKCS12 requirement)
```

And update the signing config in build.gradle.kts section:
```kotlin
// For PKCS12 keystores, storePassword and keyPassword must be identical
keyPassword = storePassword
```

---

## Part 5: Implementation Tasks

### Phase 1: Command Refactoring (Priority: High)

| Task | File | Action |
|------|------|--------|
| 1.1 | `commands/devtools/android-release-setup.md` | Refactor to pass-through |
| 1.2 | `commands/devtools/android-e2e-tests.md` | Refactor to pass-through |
| 1.3 | `commands/devtools/android-release-validate.md` | Refactor to pass-through |
| 1.4 | `commands/devtools/android-playstore-setup.md` | Refactor to pass-through |
| 1.5 | `commands/devtools/android-playstore-publish.md` | Refactor to pass-through |
| 1.6 | `commands/devtools/android-playstore-pipeline.md` | Convert to document-only orchestration |
| 1.7 | All other commands | Review and refactor if duplicating skills |

### Phase 2: Skill Bug Fixes (Priority: High)

| Task | File | Action |
|------|------|--------|
| 2.1 | `skills/android-release-build-setup/SKILL.md` | Fix PKCS12 password issue |
| 2.2 | Same file | Add explicit `-storetype PKCS12` |
| 2.3 | Same file | Update signing config to use same password |

### Phase 3: Skill Decomposition (Priority: Medium)

| Task | Action |
|------|--------|
| 3.1 | Create `android-keystore-generation/SKILL.md` |
| 3.2 | Create `android-proguard-setup/SKILL.md` |
| 3.3 | Create `android-signing-config/SKILL.md` |
| 3.4 | Refactor `android-release-build-setup/SKILL.md` to reference new skills |
| 3.5 | Create `android-espresso-dependencies/SKILL.md` |
| 3.6 | Create `android-test-structure/SKILL.md` |
| 3.7 | Create `android-sample-tests/SKILL.md` |
| 3.8 | Refactor `android-e2e-testing-setup/SKILL.md` to reference new skills |
| 3.9 | Similar decomposition for playstore skills |

### Phase 4: Documentation Updates (Priority: Medium)

| Task | File | Action |
|------|------|--------|
| 4.1 | `README.md` | Update to reflect new architecture |
| 4.2 | `INDEX.md` | Update skill index |
| 4.3 | Create `ARCHITECTURE.md` | Document command/skill/MCP relationship |

### Phase 5: MCP Tool Implementation (Priority: Future)

This is covered in the separate `devtools-mcp-implementation-plan.md` document.

---

## Validation Criteria

### For Command Refactoring

Each refactored command should:
- [ ] Be under 50 lines
- [ ] Reference skill file path explicitly
- [ ] Have clear completion criteria checkboxes
- [ ] Have single verification command
- [ ] Not duplicate skill implementation details

### For Skill Decomposition

Each new skill should:
- [ ] Do ONE thing
- [ ] Have 3 or fewer steps
- [ ] Have single verification command
- [ ] Be completable in under 5 minutes
- [ ] Have clear inputs/outputs table

### For Bug Fixes

- [ ] PKCS12 password issue fixed
- [ ] Tested on real Android project
- [ ] `./gradlew assembleRelease` succeeds without manual password fix

---

## Appendix A: Full Command Refactoring Examples

### android-e2e-tests.md (Refactored)

```markdown
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
```

### android-playstore-pipeline.md (Document-Only Orchestration)

```markdown
---
description: Complete Android Play Store pipeline setup guide
---

# Android Play Store Pipeline

Guide for setting up complete deployment pipeline. Run each command individually for best reliability.

## ⚠️ Manual Orchestration Required

Each command below should be run separately, verifying completion before proceeding.

**Why?** Multi-step orchestration has ~40-60% reliability. Individual commands have ~95% reliability.

**Future:** MCP tool `@hitoshura25/mcp-android` will automate with 95% reliability.

## Step-by-Step Execution

### Step 1: Release Build Setup

```
/devtools:android-release-setup
```

**Verify before continuing:**
```bash
./gradlew assembleRelease
ls app/build/outputs/apk/release/app-release.apk
```

---

### Step 2: E2E Testing

```
/devtools:android-e2e-tests
```

**Verify before continuing:**
```bash
./gradlew connectedDebugAndroidTest
```

---

### Step 3: Release Validation

```
/devtools:android-release-validate
```

**Verify before continuing:**
```bash
./gradlew connectedReleaseAndroidTest
```

---

### Step 4: Play Store Setup

```
/devtools:android-playstore-setup
```

**Verify before continuing:**
- Service account created
- API enabled
- Permissions granted
- `python3 scripts/validate-playstore.py` passes

---

### Step 5: Publishing Workflows

```
/devtools:android-playstore-publish
```

**Verify before continuing:**
```bash
yamllint .github/workflows/deploy-*.yml
```

---

## Complete Pipeline Verification

After all steps complete:

```bash
# Full verification
./gradlew clean
./gradlew assembleRelease
./gradlew connectedReleaseAndroidTest
ls app/build/outputs/mapping/release/mapping.txt
```

## Time Estimate

- Step 1: ~5 minutes
- Step 2: ~5 minutes
- Step 3: ~10 minutes (includes build)
- Step 4: ~15 minutes (manual Google Cloud setup)
- Step 5: ~5 minutes

**Total:** ~40 minutes

## Next Steps After Pipeline Setup

1. Add GitHub Secrets (see `distribution/GITHUB_SECRETS.md`)
2. Setup GitHub Environment for production approval
3. Push to main → deploys to internal track
4. Tag release (v1.0.0) → deploys to production
```

---

## Appendix B: Decomposed Skill Example

### android-keystore-generation/SKILL.md

```markdown
---
name: android-keystore-generation
description: Generate production and local development keystores for Android release signing
category: android
version: 1.0.0
inputs:
  - project_path: Path to Android project
  - organization: Organization name for certificate
  - country_code: 2-letter country code (optional)
outputs:
  - keystores/production-release.jks
  - keystores/local-dev-release.jks
  - keystores/KEYSTORE_INFO.txt
verify: "ls keystores/*.jks && cat keystores/KEYSTORE_INFO.txt"
---

# Android Keystore Generation

Generates dual keystores for Android release signing: production (CI/CD only) and local development.

## Prerequisites

- JDK installed (`keytool` command available)
- Write access to project directory

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| project_path | Yes | . | Android project root |
| organization | Yes | - | Organization name for certificate DN |
| country_code | No | US | 2-letter country code |

## Process

### Step 1: Create Keystores Directory

```bash
mkdir -p keystores
```

### Step 2: Generate Production Keystore

**SECURITY:** This keystore is for CI/CD only. Never use locally.

```bash
# Generate secure password (PKCS12 requires same for store and key)
PROD_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)

keytool -genkeypair -v \
  -keystore keystores/production-release.jks \
  -storetype PKCS12 \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$PROD_PASSWORD" \
  -keypass "$PROD_PASSWORD" \
  -dname "CN=Android Release, OU=Release, O=${ORGANIZATION}, C=${COUNTRY_CODE}"
```

### Step 3: Generate Local Development Keystore

```bash
# Generate separate password for local keystore
LOCAL_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)

keytool -genkeypair -v \
  -keystore keystores/local-dev-release.jks \
  -storetype PKCS12 \
  -alias local-dev \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$LOCAL_PASSWORD" \
  -keypass "$LOCAL_PASSWORD" \
  -dname "CN=Local Development, OU=Development, O=Local, C=US"
```

### Step 4: Create Credentials File

```bash
cat > keystores/KEYSTORE_INFO.txt << EOF
Production Keystore
===================
File: production-release.jks
Alias: upload
Store Password: $PROD_PASSWORD
Key Password: $PROD_PASSWORD (same as store - PKCS12 requirement)

⚠️ SECURITY: CI/CD ONLY - Never use on developer machines

GitHub Secrets:
  SIGNING_KEY_STORE_BASE64: $(base64 -w 0 keystores/production-release.jks)
  SIGNING_KEY_ALIAS: upload
  SIGNING_STORE_PASSWORD: $PROD_PASSWORD
  SIGNING_KEY_PASSWORD: $PROD_PASSWORD

---

Local Development Keystore
==========================
File: local-dev-release.jks
Alias: local-dev
Store Password: $LOCAL_PASSWORD
Key Password: $LOCAL_PASSWORD

Add to ~/.gradle/gradle.properties:
  SIGNING_KEY_STORE_PATH=$(pwd)/keystores/local-dev-release.jks
  SIGNING_KEY_ALIAS=local-dev
  SIGNING_STORE_PASSWORD=$LOCAL_PASSWORD
  SIGNING_KEY_PASSWORD=$LOCAL_PASSWORD
EOF
```

### Step 5: Update .gitignore

```bash
# Add to .gitignore if not present
grep -q "keystores/" .gitignore 2>/dev/null || echo "keystores/" >> .gitignore
grep -q "*.jks" .gitignore 2>/dev/null || echo "*.jks" >> .gitignore
```

## Verification

**MANDATORY:** Run these commands:

```bash
# Verify keystores exist
ls -la keystores/*.jks

# Verify credentials documented
cat keystores/KEYSTORE_INFO.txt

# Verify gitignored
grep "keystores" .gitignore
```

**Expected output:**
- Two .jks files in keystores/
- KEYSTORE_INFO.txt with passwords
- keystores/ in .gitignore

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| Production keystore | keystores/production-release.jks | For CI/CD only |
| Local keystore | keystores/local-dev-release.jks | For local testing |
| Credentials | keystores/KEYSTORE_INFO.txt | Passwords and setup info |

## Troubleshooting

### "keytool: command not found"
**Cause:** JDK not installed or not in PATH
**Fix:** Install JDK 17: `brew install openjdk@17` (macOS) or `apt install openjdk-17-jdk` (Linux)

### "openssl: command not found"
**Cause:** OpenSSL not installed
**Fix:** Use alternative password generation: `head -c 24 /dev/urandom | base64`

## Completion Criteria

- [ ] `keystores/production-release.jks` exists
- [ ] `keystores/local-dev-release.jks` exists
- [ ] `keystores/KEYSTORE_INFO.txt` exists with passwords
- [ ] `keystores/` is in `.gitignore`
```

---

## Summary

This spec provides:

1. **Command template** for pass-through refactoring
2. **Skill decomposition plan** for single-purpose skills
3. **Bug fix** for PKCS12 password issue
4. **Orchestration strategy** (document-only now, MCP tool later)
5. **Implementation tasks** in priority order
6. **Validation criteria** for each change

The changes maintain backward compatibility while improving reliability and maintainability.
