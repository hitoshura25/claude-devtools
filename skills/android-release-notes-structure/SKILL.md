---
name: android-release-notes-structure
description: Create Play Store release notes directory structure with locale templates
category: android
version: 1.0.0
inputs:
  - locales: List of locales to support (default: en-US)
outputs:
  - distribution/whatsnew/ directory structure
  - distribution/TRACKS.md
verify: "test -d distribution/whatsnew/en-US"
---

# Android Release Notes Structure

Creates directory structure for Play Store release notes with multi-locale support.

## Prerequisites

- Android project

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| locales | No | en-US | Comma-separated locales (e.g., en-US,de-DE,es-ES) |

## Process

### Step 1: Create Release Notes Directory Structure

```bash
# Create base directory
mkdir -p distribution/whatsnew

# Ask user which locales to support
# Default: en-US
# Common: en-US, de-DE, es-ES, fr-FR, it-IT, ja-JP, ko-KR, pt-BR, zh-CN, zh-TW

# Create directories for each locale
for locale in ${LOCALES}; do
  mkdir -p "distribution/whatsnew/${locale}"
done
```

### Step 2: Create Template Whatsnew Files

For each locale, create `distribution/whatsnew/${LOCALE}/whatsnew`:

```bash
cat > distribution/whatsnew/en-US/whatsnew << 'EOF'
- New: [Feature name]
- Improved: [Enhancement description]
- Fixed: [Bug fix description]

Note: Keep under 500 characters. Focus on user-visible changes.
EOF
```

### Step 3: Create Release Notes README

Create `distribution/whatsnew/README.md`:

```markdown
# Play Store Release Notes

This directory contains release notes for Google Play Store deployments.

## Structure

Each locale has its own directory with a `whatsnew` file (no extension):

```
whatsnew/
├── en-US/
│   └── whatsnew
├── de-DE/
│   └── whatsnew
└── [other locales]/
    └── whatsnew
```

## Format Guidelines

**File Requirements:**
- File name: `whatsnew` (no extension)
- Encoding: UTF-8
- Maximum: 500 characters
- Plain text only (no markdown/HTML)

**Content Guidelines:**
- Focus on user-visible changes
- List most important first
- Use bullet points (-, •, or *)
- Be concise and clear
- Avoid technical jargon

## Example Release Notes

**Good:**
```
- New dark mode for easier nighttime reading
- Improved app startup speed by 50%
- Fixed crash when uploading large photos
- Updated design for better accessibility
```

**Avoid:**
```
- Refactored codebase architecture
- Updated dependencies to latest versions
- Various bug fixes and improvements
- Performance optimizations
```

## Supported Locales

Current locales: ${LOCALES}

To add a locale:
1. Create directory: `mkdir -p whatsnew/LOCALE-CODE`
2. Create file: `touch whatsnew/LOCALE-CODE/whatsnew`
3. Add translated release notes

## Common Locales

- en-US: English (United States)
- de-DE: German (Germany)
- es-ES: Spanish (Spain)
- fr-FR: French (France)
- it-IT: Italian (Italy)
- ja-JP: Japanese (Japan)
- ko-KR: Korean (Korea)
- pt-BR: Portuguese (Brazil)
- zh-CN: Chinese (Simplified)
- zh-TW: Chinese (Traditional)

## Updating Release Notes

Before each release:
1. Update `whatsnew` files for all locales
2. Keep under 500 characters
3. Verify UTF-8 encoding
4. Test locally: `wc -m whatsnew/en-US/whatsnew`
```

### Step 4: Create Tracks Documentation

Create `distribution/TRACKS.md`:

```markdown
# Google Play Store Release Tracks

Complete guide to Play Store release tracks and workflow.

## Track Types

### 1. Internal Testing
**Audience:** Up to 100 testers (team only)
**Review:** None (instant, < 1 minute)
**Best for:** Daily builds, CI/CD, quick iterations
**Access:** Email-based tester list

**Use when:**
- Testing new features rapidly
- Verifying CI/CD pipeline
- Quick bug fix validation

### 2. Closed Testing (Beta)
**Audience:** Unlimited invited testers
**Review:** Typically < 1 day
**Best for:** Beta program, QA team, stakeholders
**Access:** Email list or shareable link

**Use when:**
- Extended testing with real users
- Collecting feedback before public release
- Testing with diverse devices/OS versions

### 3. Open Testing
**Audience:** Anyone with the link
**Review:** 1-7 days (first submission)
**Best for:** Public beta, community testing
**Access:** Public Play Store link

**Use when:**
- Large-scale public beta
- Community-driven feature testing
- Stress testing infrastructure

### 4. Production
**Audience:** All users (or staged rollout)
**Review:** 1-7 days (first submission, then hours)
**Best for:** Official releases
**Rollout:** Staged (5% → 10% → 50% → 100%)

**Use when:**
- Ready for public release
- All testing complete
- Version approved for general availability

## Recommended Workflow

```
Development
    ↓
Push to main → Internal Testing (auto)
    ↓
Test & validate
    ↓
Deploy to Beta → Closed Testing (manual)
    ↓
Beta feedback (1-2 weeks)
    ↓
Tag release → Production (manual approval)
    ↓
Staged Rollout:
  Day 1: 5%  → Monitor crash-free rate
  Day 2: 20% → Monitor ANR rate
  Day 3: 50% → Monitor user feedback
  Day 5: 100% → Complete rollout
```

## Promotion Between Tracks

**Internal → Closed:**
- Manual promotion in Play Console
- Or automated via GitHub Actions workflow

**Closed → Production:**
- Always requires manual approval
- Create GitHub release tag
- Triggers production deployment workflow

**Emergency Halt:**
If issues detected:
1. Run manage-rollout workflow with "halt" action
2. Fix issue
3. Deploy new version
4. Resume or start new rollout

## Best Practices

1. **Always test in Internal first**
   - Never skip to production
   - Catch obvious issues early

2. **Use Closed Testing for Beta**
   - Get real user feedback
   - Test on diverse devices
   - Minimum 1 week beta period

3. **Staged Production Rollouts**
   - Start at 5-10%
   - Monitor for 24-48 hours
   - Only increase if crash-free rate > 99%

4. **Monitor Key Metrics**
   - Crash-free rate (target: > 99.5%)
   - ANR rate (target: < 0.5%)
   - User ratings
   - Install/uninstall rates

5. **Have Rollback Plan**
   - Keep previous version available
   - Can halt rollout anytime
   - Can decrease rollout percentage
```

## Verification

**MANDATORY:** Run these commands:

```bash
# Verify directory structure
test -d distribution/whatsnew/en-US && echo "✓ Release notes structure created"

# Verify whatsnew files exist
ls distribution/whatsnew/*/whatsnew && echo "✓ Whatsnew files created"

# Verify documentation
test -f distribution/whatsnew/README.md && echo "✓ README created"
test -f distribution/TRACKS.md && echo "✓ TRACKS guide created"

# Check character count (should be < 500)
wc -m distribution/whatsnew/en-US/whatsnew
```

**Expected output:**
- ✓ Release notes structure created
- ✓ Whatsnew files created
- ✓ README created
- ✓ TRACKS guide created
- Character count < 500

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| Release notes | distribution/whatsnew/${LOCALE}/ | Per-locale release notes |
| README | distribution/whatsnew/README.md | Usage documentation |
| Tracks guide | distribution/TRACKS.md | Release workflow guide |

## Troubleshooting

### "Character limit exceeded"
**Cause:** Whatsnew file > 500 characters
**Fix:** Edit file to be more concise, focus on top 3-4 changes

### "Encoding issues"
**Cause:** Non-UTF-8 encoding
**Fix:** Save files as UTF-8: `iconv -f ISO-8859-1 -t UTF-8 whatsnew`

## Completion Criteria

- [ ] `distribution/whatsnew/` directory exists
- [ ] At least `en-US/whatsnew` file exists
- [ ] `whatsnew/README.md` created
- [ ] `distribution/TRACKS.md` created
- [ ] All whatsnew files are < 500 characters
