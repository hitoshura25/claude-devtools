---
name: android-playstore-setup
description: Complete Play Console setup - orchestrates service account, release notes, and API validation
category: android
version: 2.0.0
---

# Android Play Store Setup

This skill orchestrates complete Google Play Console setup by running three atomic skills in sequence.

## What This Does

Sets up everything needed for Play Store deployment:
1. **Service Account Guide** - Google Cloud service account creation
2. **Release Notes Structure** - Multi-locale release notes directories
3. **API Validation** - Test Play Store API connection

## Prerequisites

- Google Play Developer account ($25 one-time)
- Google Cloud Platform account (free)
- Admin access to Play Console
- Package name reserved in Play Console

## Process

This skill runs three sub-skills in order:

### Step 1: Service Account Setup

Follow the skill at: `~/claude-devtools/skills/android-service-account-guide/SKILL.md`

**What it does:**
- Provides step-by-step Google Cloud setup guide
- Documents service account creation process
- Creates Play Console setup documentation
- Creates GitHub Secrets documentation

**Verify before continuing:**
- User confirms service account created
- User confirms JSON key downloaded
- User confirms permissions granted

---

### Step 2: Create Release Notes Structure

Follow the skill at: `~/claude-devtools/skills/android-release-notes-structure/SKILL.md`

**What it does:**
- Creates distribution/whatsnew/ directories
- Creates locale-specific folders
- Generates whatsnew file templates
- Creates tracks documentation

**Verify before continuing:**
```bash
test -d distribution/whatsnew/en-US
ls distribution/whatsnew/*/whatsnew
```

---

### Step 3: Validate API Connection

Follow the skill at: `~/claude-devtools/skills/android-playstore-api-validation/SKILL.md`

**What it does:**
- Creates validation Python script
- Tests Play Store API connection
- Verifies service account permissions
- Confirms package access

**Verify before continuing:**
```bash
python3 scripts/validate-playstore.py SERVICE_ACCOUNT.json PACKAGE_NAME
```

---

## Final Verification (MANDATORY)

After all three skills complete, verify the complete setup:

```bash
# 1. Verify documentation exists
test -f distribution/PLAY_CONSOLE_SETUP.md && echo "✓ Setup guide created"
test -f distribution/GITHUB_SECRETS.md && echo "✓ Secrets guide created"

# 2. Verify release notes structure
test -d distribution/whatsnew/en-US && echo "✓ Release notes structure created"

# 3. Verify validation script
test -f scripts/validate-playstore.py && echo "✓ Validation script created"

# 4. Run API validation
python3 scripts/validate-playstore.py /path/to/service-account.json com.example.app
```

**All checks must pass** before marking this skill as complete.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

✅ **Service Account Setup**
  - [ ] Service account created in Google Cloud
  - [ ] JSON key downloaded and stored securely
  - [ ] Play Developer API enabled
  - [ ] Service account linked to Play Console
  - [ ] "Release" permission granted

✅ **Release Notes Structure**
  - [ ] distribution/whatsnew/ directory exists
  - [ ] At least en-US locale created
  - [ ] Whatsnew files created
  - [ ] TRACKS.md documentation created

✅ **API Validation**
  - [ ] scripts/validate-playstore.py exists
  - [ ] Validation script runs successfully
  - [ ] API connection confirmed
  - [ ] Package access confirmed

✅ **Documentation**
  - [ ] distribution/PLAY_CONSOLE_SETUP.md exists
  - [ ] distribution/GITHUB_SECRETS.md exists

## Summary Report

After completion, provide this summary:

```
✅ Android Play Store Setup Complete!

🔐 Service Account:
  ✓ Created in Google Cloud
  ✓ JSON key downloaded
  ✓ Linked to Play Console
  ✓ Permissions granted

📝 Release Notes:
  ✓ Structure created: distribution/whatsnew/
  ✓ Locales configured
  ✓ Templates ready

✅ API Validation:
  ✓ Validation script created
  ✓ API connection tested
  ✓ Package access confirmed

📋 Next Steps:

  For GitHub:
    1. Add secrets (see distribution/GITHUB_SECRETS.md)
    2. Create "production" environment with reviewers

  For Deployment:
    1. Run: /devtools:android-playstore-publish
    2. Generate deployment workflows

⚠️  CRITICAL REMINDERS:
  - NEVER commit service account JSON to git
  - Store JSON key in password manager
  - Add all 5 secrets to GitHub before deploying
  - Wait 5-10 minutes after granting permissions
```

## Integration with Other Skills

This skill is prerequisite for:
- `android-playstore-publishing` - Uses service account for deployment
- `android-playstore-pipeline` - Complete pipeline setup

## Troubleshooting

If any skill fails:
1. Fix the specific issue in that skill
2. Re-run that skill until it completes
3. Continue with remaining skills
4. Run final verification

Common issues:
- **Service account not found** → Check Google Cloud project
- **Permissions denied** → Grant "Release" permission
- **API validation fails** → Wait 5-10 minutes for propagation
