---
description: Complete Android Play Store deployment pipeline setup in one command - orchestrates all 5 deployment skills
---

# Android Play Store Pipeline

The "easy button" for Android deployment! Sets up your complete Play Store deployment pipeline from scratch in one command.

## What This Command Does

Orchestrates all five Android skills to create a production-ready deployment pipeline:

1. ✅ **Release Build** - Keystores, ProGuard, signing
2. ✅ **E2E Testing** - Espresso tests and CI/CD
3. ✅ **Validation** - Quality gates, release checks
4. ✅ **Play Console** - API integration, service account
5. ✅ **CI/CD Deployment** - GitHub Actions workflows

All configured in **~15 minutes** with interactive guidance!

## Usage

```bash
/devtools:android-playstore-pipeline
```

## What You Get

**Complete deployment system:**
- Production & dev keystores (secure)
- ProGuard/R8 configuration (safe defaults)
- E2E test suite (Espresso)
- Quality validation (automated)
- Play Console integration (service account)
- CI/CD workflows (4 deployment workflows)
- Documentation (comprehensive guides)

**Deployment flow:**
```
Push to main → Internal (auto) → Beta (manual) → Production (staged)
```

## Prerequisites

**Required:**
- Android project with Gradle
- Package name decided
- Google Play Developer account ($25)

**NOT Required:**
- Existing keystore (we create it)
- Existing tests (we generate samples)
- CI/CD experience (we set it up)

## Interactive Setup

One questionnaire, complete setup:

**Project:**
- Package name
- App name
- Main activity

**Organization:**
- Name, unit, city, state, country

**Testing:**
- Locales for release notes
- Test orchestrator preference

**Deployment:**
- Which tracks (internal/beta/production)
- Production approval requirement

**Play Console:**
- Setup now or manual later

## What Gets Created

**Security & Build:**
```
keystores/
  ├── production-release.jks (CI/CD only)
  ├── local-dev-release.jks (local testing)
  └── KEYSTORE_INFO.txt (passwords - SECURE!)
app/proguard-rules.pro (safe defaults)
gradle.properties.template (local signing)
```

**Tests:**
```
app/src/androidTest/
  ├── base/BaseTest.kt
  ├── ExampleInstrumentedTest.kt (smoke)
  ├── screens/MainActivityTest.kt (navigation)
  └── utils/ (helpers, screenshots)
```

**Play Console:**
```
distribution/
  ├── whatsnew/ (release notes)
  ├── PLAY_CONSOLE_SETUP.md (guide)
  ├── GITHUB_SECRETS.md (secrets)
  └── TRACKS.md (track types)
```

**CI/CD:**
```
.github/workflows/
  ├── deploy-internal.yml (auto on push)
  ├── deploy-beta.yml (manual)
  ├── deploy-production.yml (staged)
  ├── manage-rollout.yml (control)
  ├── android-test.yml (E2E tests)
  └── release-validation.yml (quality)
```

## After Setup

**Critical - Secure Keystores:**
1. Open `keystores/KEYSTORE_INFO.txt`
2. Copy passwords to password manager
3. Back up keystores securely
4. NEVER commit keystores!

**GitHub Secrets (5 required):**
1. SERVICE_ACCOUNT_JSON
2. SIGNING_KEY_STORE_BASE64
3. SIGNING_KEY_ALIAS
4. SIGNING_STORE_PASSWORD
5. SIGNING_KEY_PASSWORD

See: `distribution/GITHUB_SECRETS.md`

**Play Console Setup (~10 min):**
1. Create service account
2. Enable API
3. Link to Play Console
4. Download JSON key

See: `distribution/PLAY_CONSOLE_SETUP.md`

**GitHub Environment:**
1. Settings → Environments
2. Create "production"
3. Add required reviewers

**First Deployment:**
```bash
# Update release notes
vim distribution/whatsnew/en-US/whatsnew

# Push to deploy to internal
git add .
git commit -m "Add deployment pipeline"
git push origin main

# Watch GitHub Actions
# Test on device

# Tag for production
git tag v1.0.0
git push origin v1.0.0
# Approve in GitHub → Staged rollout
```

## Time Breakdown

- **Interactive questions:** 3 minutes
- **Automated setup:** 12 minutes
  - Skill 1 (Build): 2 min
  - Skill 2 (Tests): 3 min
  - Skill 3 (Validation): 2 min
  - Skill 4 (Play Console): 2 min
  - Skill 5 (CI/CD): 3 min
- **Manual steps:** 15-20 minutes
  - Play Console setup: 10 min
  - GitHub Secrets: 5 min
  - Environment setup: 2 min

**Total:** ~30 minutes to full deployment pipeline

## Deployment Workflow

```
Development
  ↓
Push to main
  ↓
Internal Testing (automatic, <5 min)
  ↓
Test on device
  ↓
Deploy to Beta (manual trigger)
  ↓
Beta Testing (1-2 weeks)
  ↓
Tag v1.0.0
  ↓
Production (requires approval)
  ↓
5% Rollout → Monitor 24-48h
  ↓
Increase to 20% → Monitor
  ↓
Increase to 50% → Monitor
  ↓
Complete to 100%
```

## Features

**Security First:**
- Keystores never in git
- Secrets in GitHub Secrets
- Environment protection
- Audit trails

**Quality Gates:**
- E2E tests on release
- ProGuard validation
- Signing verification
- Size checks

**Staged Rollouts:**
- Start at 5%
- Monitor crash rates
- Gradual increase
- Emergency halt

**Complete Documentation:**
- Setup guides
- Workflow usage
- Troubleshooting
- Best practices

## Skill Reference

This command uses the skill at:
`~/.claude/skills/user/devtools/android-playstore-pipeline/SKILL.md`

This orchestrates all five prerequisite skills:
- android-release-build-setup
- android-e2e-testing-setup
- android-release-validation
- android-playstore-setup
- android-playstore-publishing

## Example Session

```
User: /devtools:android-playstore-pipeline

Claude: I'll set up your complete Android Play Store deployment pipeline!

This will configure everything you need to deploy to Play Store with CI/CD.

Estimated time: 15 minutes automated + 15 minutes manual setup

Ready to begin? (y/n)
→ y

=== Project Information ===

What is your app's package name?
(e.g., com.example.myapp)
→ com.example.myapp

What is your app name?
→ My Awesome App

What is your main activity class name?
→ MainActivity

=== Organization Information ===

Organization name?
→ Example Corp

Organization unit?
→ Engineering

City?
→ San Francisco

State/Province?
→ California

Country code (2 letters)?
→ US

=== Testing Configuration ===

Which locales for release notes? (comma-separated)
(default: en-US)
→ en-US, de-DE, es-ES

Enable test orchestrator for better isolation?
(recommended for large test suites)
→ yes

=== Deployment Configuration ===

Which deployment tracks to enable?
  [x] Internal (continuous deployment)
  [x] Beta (alpha/beta testing)
  [x] Production (staged rollout)
→ all

Enable manual approval for production deployments?
(highly recommended for safety)
→ yes

=== Confirmation ===

I'll now set up:
  ✓ Release build with keystores and ProGuard
  ✓ E2E testing with Espresso
  ✓ Release validation
  ✓ Play Console integration
  ✓ CI/CD deployment workflows

This will create ~30 files and modify build.gradle.kts

Continue? (y/n)
→ y

╔════════════════════════════════════════╗
║  Starting Pipeline Setup...            ║
╚════════════════════════════════════════╝

=== Step 1/5: Release Build Setup ===
  ✓ Generated production keystore
  ✓ Generated local dev keystore
  ✓ Configured ProGuard/R8
  ✓ Updated build.gradle.kts
  ⏱ 2 minutes

=== Step 2/5: E2E Testing Setup ===
  ✓ Added Espresso dependencies
  ✓ Created test structure
  ✓ Generated sample tests
  ⏱ 3 minutes

=== Step 3/5: Release Validation ===
  ✓ Created validation workflows
  ✓ Configured quality gates
  ⏱ 2 minutes

=== Step 4/5: Play Console Setup ===
  ✓ Created release notes structure
  ✓ Generated setup guides
  ⏱ 2 minutes

=== Step 5/5: CI/CD Deployment ===
  ✓ Created deployment workflows
  ✓ Generated documentation
  ⏱ 3 minutes

╔════════════════════════════════════════╗
║  🎉 Pipeline Setup Complete! 🎉       ║
╚════════════════════════════════════════╝

⏱ Total time: 12 minutes

📋 Next Steps:

  1. CRITICAL - Secure keystores:
     • Open: keystores/KEYSTORE_INFO.txt
     • Save passwords in password manager
     • Back up keystores securely

  2. Setup GitHub Secrets (5 required):
     • See: distribution/GITHUB_SECRETS.md

  3. Setup Play Console (~10 min):
     • See: distribution/PLAY_CONSOLE_SETUP.md

  4. Create GitHub Environment:
     • Settings → Environments → "production"

  5. First deployment:
     • git push origin main
     • Deploys to internal automatically!

📖 Documentation created:
  • distribution/PLAY_CONSOLE_SETUP.md
  • distribution/GITHUB_SECRETS.md
  • distribution/TRACKS.md
  • .github/workflows/README.md

Your Android deployment pipeline is ready! 🚀
```

## Troubleshooting

**"Not an Android project"**
→ Run from project root (where app/ directory is)

**"Package name not found"**
→ Add to build.gradle.kts: `namespace = "com.example.app"`

**"Pipeline fails partway"**
→ Fix error and re-run - completed steps preserved

## Notes

- First Play Console upload MUST be manual
- Keystores are generated with secure random passwords
- All secrets go in GitHub Secrets (never git)
- Production requires manual approval for safety
- Use staged rollouts starting at 5%

This is the complete, production-ready setup. After manual steps, you have full CI/CD deployment to Play Store!
