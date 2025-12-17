---
description: Setup technology-agnostic version management with Git tags as source of truth
---

# Version Management

Sets up semantic versioning using Git tags as the source of truth, with platform-specific adapters for fast builds.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/version-management/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] `scripts/version-manager.sh` exists and is executable
- [ ] Platform adapter exists (e.g., `scripts/gradle-version.sh`)
- [ ] Version file created (e.g., `version.properties` for Gradle)
- [ ] Build configuration reads from version file
- [ ] `./scripts/version-manager.sh latest` runs successfully

## Quick Reference

**Inputs:** Project path, platform (gradle/npm/python)
**Outputs:** Version scripts, version file, build config updates
**Verify:** `./scripts/version-manager.sh latest && ./scripts/version-manager.sh generate patch`

## Supported Platforms

| Platform | Adapter | Version File |
|----------|---------|--------------|
| Gradle/Android | `gradle-version.sh` | `version.properties` |
| npm (future) | `npm-version.sh` | `package.json` |
| Python (future) | `python-version.sh` | `__init__.py` |

## Related Commands

- `/devtools:android-playstore-setup` - Uses version management for releases
- `/devtools:android-release-setup` - Release build configuration
