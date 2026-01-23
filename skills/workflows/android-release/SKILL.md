---
name: android-release
description: Use when deploying Android apps to Play Store internal, beta, or production tracks
---

# Android Release

## Overview

Complete Android release workflow: version bump, signing, Fastlane deployment to Play Store.

## Prerequisites

- **Quality gates passed:** All tests, lint, security, and AI review must pass
- **Fastlane configured:** See `references/fastlane-setup.md`
- **Signing configured:** See `references/signing.md`
- **Play Store access:** Service account with API permissions

## The Rule

```
NO RELEASE WITHOUT ALL QUALITY GATES PASSING
No "hotfix without tests". No "quick deploy".
Every release goes through the full pipeline.
```

## Release Tracks

| Track | Purpose | Rollout |
|-------|---------|---------|
| **internal** | Team testing | Immediate, <100 testers |
| **beta** | External testing | Staged, selected users |
| **production** | Public release | Staged rollout (10% → 50% → 100%) |

## Process

### 1. Verify Quality Gates

```bash
# All must have passed in this session:
# ✓ Tests passing
# ✓ Lint clean
# ✓ Security scan clean
# ✓ AI review complete (if configured)

# Verify tests pass now
./gradlew test
```

### 2. Bump Version

```bash
# Generate next version
./scripts/gradle-version.sh generate patch  # or minor/major

# Update version.properties
./scripts/gradle-version.sh update

# Verify
cat version.properties
```

### 3. Build Release Bundle

```bash
./gradlew bundleRelease
```

Verify output:
```bash
ls -la app/build/outputs/bundle/release/app-release.aab
```

### 4. Deploy to Track

**Internal (team testing):**
```bash
bundle exec fastlane deploy_internal
```

**Beta (staged rollout):**
```bash
# 10% rollout
bundle exec fastlane deploy_beta rollout:0.1

# Full rollout
bundle exec fastlane deploy_beta rollout:1.0
```

**Production (staged rollout):**
```bash
# Start with 10%
bundle exec fastlane deploy_production rollout:0.1

# Increase to 50% after monitoring
bundle exec fastlane increase_rollout rollout:0.5

# Full rollout
bundle exec fastlane increase_rollout rollout:1.0
```

### 5. Tag Release

```bash
VERSION=$(cat version.properties | grep VERSION_NAME | cut -d= -f2)
git add version.properties
git commit -m "chore: bump version to $VERSION"
git tag "v$VERSION"
git push origin main
git push origin "v$VERSION"
```

### 6. Verify Deployment

1. Check Play Console for new release
2. Verify version number matches
3. Monitor crash reports for 24 hours
4. Proceed with rollout increase if stable

## Emergency: Halt Rollout

If issues are discovered:

```bash
bundle exec fastlane halt_rollout
```

This stops rollout at current percentage. Users who already updated keep the version.

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Hotfix, no time for tests" | Hotfixes need tests MORE. Production is at stake. |
| "Just metadata change" | Still goes through pipeline. No exceptions. |
| "Already tested on device" | Manual testing ≠ automated gates. Run them. |
| "Rollback is easy" | Users already got bad build. Prevention > cure. |
| "It's internal track" | Internal still needs quality. Build habits. |

## Red Flags - STOP

- Deploying without quality gates passing
- Skipping version bump
- Deploying to production without staged rollout
- Ignoring crash reports during rollout
- "Quick fix" bypassing process

**If you catch yourself doing any of these: STOP. Follow the process.**

## Rollout Strategy

### Recommended Production Rollout

| Day | Percentage | Action |
|-----|------------|--------|
| 1 | 10% | Deploy, monitor crashes |
| 2-3 | 10% | Continue monitoring |
| 4 | 50% | Increase if stable |
| 5-6 | 50% | Continue monitoring |
| 7 | 100% | Full rollout if stable |

### When to Halt

- Crash rate > 0.5%
- ANR rate > 0.1%
- Negative reviews mentioning bugs
- Critical functionality broken

## Verification

```bash
# Verify service account works
bundle exec fastlane run validate_play_store_json_key

# Check current production version
bundle exec fastlane run google_play_track_version_codes track:production
```

## References

- `references/fastlane-setup.md` - Fastlane configuration
- `references/signing.md` - Keystore and signing config
- `references/playstore.md` - Play Store API setup
- `references/rollout.md` - Staged rollout best practices
