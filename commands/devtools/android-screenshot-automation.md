---
description: Setup automated screenshot capture for Play Store using Fastlane Screengrab
---

# Android Screenshot Automation

Configures Fastlane Screengrab for automated screenshot capture across locales and devices.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-screenshot-automation/SKILL.md`

## Completion Criteria

- [ ] Screengrab dependency added
- [ ] Debug manifest has required permissions
- [ ] `ScreenshotTest.kt` captures key screens
- [ ] `bundle exec fastlane screenshots` runs successfully
- [ ] Screenshots in `fastlane/metadata/android/en-US/images/phoneScreenshots/`

## Quick Reference

**Inputs:** Screens to capture, locales
**Outputs:** Screenshot test class, captured screenshots
**Verify:** `bundle exec fastlane screenshots`

## Related Commands

- `/devtools:android-fastlane-setup` - Required first
- `/devtools:android-e2e-tests` - Existing test infrastructure
