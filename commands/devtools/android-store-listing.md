---
description: Create feature graphic and complete store listing metadata
---

# Android Store Listing

Creates feature graphic, metadata templates, and provides guidance for Play Store listing.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-store-listing/SKILL.md`

## Completion Criteria

- [ ] Feature graphic at `fastlane/metadata/android/en-US/images/featureGraphic.png`
- [ ] Feature graphic is 1024x500 PNG
- [ ] `title.txt` (max 30 chars)
- [ ] `short_description.txt` (max 80 chars)
- [ ] `full_description.txt` (max 4000 chars)
- [ ] `changelogs/default.txt` exists

## Quick Reference

**Inputs:** App name, tagline, description
**Outputs:** Feature graphic, metadata files
**Verify:** `bundle exec fastlane upload_metadata --skip_upload_images`

## Related Commands

- `/devtools:android-app-icon` - App icon
- `/devtools:android-screenshot-automation` - Screenshots
- `/devtools:android-fastlane-setup` - Fastlane configuration
