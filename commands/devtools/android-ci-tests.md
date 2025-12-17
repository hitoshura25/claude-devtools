---
description: Setup GitHub Actions CI workflow for Android tests (unit, lint, instrumented)
---

# Android CI Tests

Sets up GitHub Actions workflow for comprehensive Android testing including unit tests, lint checks, and instrumented tests with emulator.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-ci-tests/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] `.github/workflows/test.yml` exists and is valid YAML
- [ ] Unit tests job configured
- [ ] Lint job configured
- [ ] Instrumented tests job with emulator configured
- [ ] AVD caching enabled for faster emulator startup
- [ ] Test results uploaded as artifacts
- [ ] All actions pinned to commit SHAs

## Quick Reference

**Inputs:** Project path
**Outputs:** `.github/workflows/test.yml`
**Verify:** `yamllint .github/workflows/test.yml`

## Workflow Jobs

| Job | Purpose | Runs On |
|-----|---------|---------|
| `unit-tests` | Run `./gradlew test` | ubuntu-latest |
| `lint` | Run `./gradlew lint` | ubuntu-latest |
| `instrumented-tests` | Run on emulator | ubuntu-latest (KVM) |

## Emulator Configuration

- API Level: 30 (Android 11)
- Target: google_apis
- Arch: x86_64
- AVD caching enabled
- KVM acceleration

## Related Commands

- `/devtools:android-e2e-tests` - End-to-end testing setup
- `/devtools:android-playstore-setup` - Includes test job in release workflow
- `/devtools:test` - General test setup
