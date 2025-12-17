---
description: Generate app icon using IconKitchen and place in correct locations
---

# Android App Icon

Guides you through IconKitchen to generate adaptive app icons, then places assets correctly.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-app-icon/SKILL.md`

## Completion Criteria

- [ ] Icon generated via IconKitchen
- [ ] Mipmap resources in `app/src/main/res/mipmap-*/`
- [ ] Play Store icon at `fastlane/metadata/android/en-US/images/icon.png`
- [ ] Icon is 512x512 PNG
- [ ] App builds successfully with new icon

## Quick Reference

**Inputs:** Logo/image file, app name, primary color
**Outputs:** Adaptive icons, Play Store icon (512x512)
**Verify:** `./gradlew assembleDebug`

## Related Commands

- `/devtools:android-store-listing` - Feature graphic and metadata
