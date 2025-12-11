---
description: Setup Google Play Console integration for automated Android app deployment
---

# Android Play Store Setup

Configures Google Play Console integration: service account, API access, release notes structure, and validation.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-playstore-setup/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Service account created in Google Cloud
- [ ] Service account JSON downloaded and stored securely
- [ ] Play Developer API enabled
- [ ] Service account linked to Play Console with "Release" permission
- [ ] Release notes directory structure created: `distribution/whatsnew/`
- [ ] Validation script passes: `python scripts/validate-playstore.py`

## Quick Reference

**Inputs:** Google Play Developer account, package name, Play Console admin access
**Outputs:** Service account, release notes structure, GitHub Secrets guide, validation script
**Verify:** `python scripts/validate-playstore.py service-account.json com.example.app`

## Prerequisites

- Google Play Developer account ($25 one-time)
- Google Cloud Platform account (free)
- Admin access to Play Console
- Package name reserved in Play Console

## Related Commands

- `/devtools:android-release-setup` - Required before this
- `/devtools:android-playstore-publish` - Run after this
- `/devtools:android-playstore-pipeline` - Complete pipeline setup
