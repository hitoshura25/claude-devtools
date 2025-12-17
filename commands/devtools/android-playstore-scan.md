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
