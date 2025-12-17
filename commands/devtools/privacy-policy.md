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
