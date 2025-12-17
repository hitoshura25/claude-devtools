---
description: Setup Fastlane for Play Store deployment with supply and screengrab
---

# Android Fastlane Setup

Configures Fastlane with supply (Play Store deployment) and screengrab (screenshot automation).

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-fastlane-setup/SKILL.md`

## Completion Criteria

- [ ] `Gemfile` exists with fastlane and screengrab
- [ ] `bundle install` succeeds
- [ ] `fastlane/Appfile` configured
- [ ] `fastlane/Fastfile` has deployment lanes
- [ ] `fastlane/Screengrabfile` configured
- [ ] Metadata directory structure created

## Quick Reference

**Inputs:** Package name, service account path
**Outputs:** Gemfile, Fastfile, Appfile, Screengrabfile, metadata structure
**Verify:** `bundle exec fastlane lanes`

## Related Commands

- `/devtools:android-screenshot-automation` - Capture screenshots
- `/devtools:android-app-icon` - Generate app icon
- `/devtools:android-store-listing` - Create store listing assets
