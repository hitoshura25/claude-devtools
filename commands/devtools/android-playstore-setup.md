---
description: Setup Google Play Console integration for automated Android app deployment
---

# Android Play Store Setup

Configure Google Play Console integration for automated app deployment. Creates service account, sets up API access, and prepares release infrastructure.

## What This Command Does

Complete Play Console setup:
- ✅ Service account creation guide (step-by-step)
- ✅ Play Developer API enablement
- ✅ Play Console permissions configuration
- ✅ Release notes structure creation
- ✅ Track configuration documentation
- ✅ GitHub Secrets setup guide
- ✅ API connection validation

## Usage

```bash
/devtools:android-playstore-setup
```

## Interactive Setup

The command will:
1. Verify you have Play Console access
2. Ask for your app's package name
3. Guide you through service account creation
4. Help you enable Play Developer API
5. Guide Play Console permissions setup
6. Create release notes directory structure
7. Document release tracks workflow
8. Generate GitHub Secrets instructions
9. Optionally validate API connection

## What Gets Created

**Documentation:**
- `distribution/whatsnew/README.md` - Release notes guide
- `distribution/TRACKS.md` - Track types and workflow
- `distribution/GITHUB_SECRETS.md` - Secrets setup instructions

**Release Notes Structure:**
```
distribution/whatsnew/
├── en-US/
│   └── whatsnew
├── de-DE/
│   └── whatsnew
└── [other locales]/
    └── whatsnew
```

**Validation Script:**
- `scripts/validate-playstore.py` - API connection tester

**Service Account:**
- Downloaded from Google Cloud (not stored in repo)
- Location: Your secure storage (password manager)

## Prerequisites

- Google Play Developer account ($25 one-time fee)
- Google Cloud Platform account (free)
- Admin access to Play Console
- Package name reserved in Play Console

## Step-by-Step Guide

### Step 1: Play Console Account

If you don't have a Play Console account:
1. Visit: https://play.google.com/console/signup
2. Pay $25 one-time registration fee
3. Complete account setup
4. Verify your identity

### Step 2: Create Service Account

**In Google Cloud Console:**
1. Create project (or use existing)
2. Navigate to: IAM & Admin → Service Accounts
3. Create service account: `playstore-deploy`
4. Download JSON key file
5. Store securely (password manager)

**Claude will provide detailed step-by-step instructions**

### Step 3: Link to Play Console

**In Play Console:**
1. Navigate to: Setup → API access
2. Link Google Cloud project
3. Grant access to service account
4. Select permissions: "Release to production"

**Claude will guide you through each screen**

### Step 4: Enable API

**In Google Cloud Console:**
1. Navigate to: APIs & Services → Library
2. Search: "Google Play Android Developer API"
3. Click "Enable"
4. Wait for activation

### Step 5: Configure Release Notes

**Claude will create:**
- Directory structure for multiple locales
- Template whatsnew files
- Documentation on format and limits
- Character count guidelines

### Step 6: Document Tracks

**Claude will explain:**
- Internal testing (team only)
- Closed testing (beta testers)
- Open testing (public beta)
- Production (public release)
- Promotion workflow

### Step 7: GitHub Secrets

**Claude will document:**
- SERVICE_ACCOUNT_JSON (from Step 2)
- How to add to GitHub repository
- Verification steps
- Security best practices

### Step 8: Validate Setup

**Optional validation:**
```bash
python scripts/validate-playstore.py service-account.json com.example.app
```

Tests:
- ✓ JSON file valid
- ✓ API connection works
- ✓ Package accessible
- ✓ Permissions correct

## After Running This Command

**You'll have:**
1. ✅ Service account created and configured
2. ✅ Play Console API access enabled
3. ✅ Release notes structure ready
4. ✅ Track workflow documented
5. ✅ GitHub Secrets instructions ready

**Next steps:**
1. Add SERVICE_ACCOUNT_JSON to GitHub Secrets
2. Update release notes (distribution/whatsnew/en-US/whatsnew)
3. Run `/devtools:android-playstore-publish` to create deployment workflow
4. Deploy your app!

## Service Account Permissions

**Minimum required:**
- Release apps to production
- Release apps to testing tracks

**Recommended:**
- View app information
- Manage testing tracks
- Edit tester lists

**Not needed:**
- Financial data access
- Order management
- User management

## Release Notes Guidelines

**Format:**
- Plain text file named `whatsnew`
- Maximum 500 characters
- UTF-8 encoding
- No file extension

**Content:**
- New features (most important first)
- Bug fixes (if significant)
- Performance improvements
- Keep user-friendly

**Example:**
```
- New: Dark mode support
- Improved: 50% faster startup
- Fixed: Crash when uploading photos
- Updated: Refreshed UI design
```

## Track Types Explained

### Internal Testing
- **Audience:** Up to 100 testers (team only)
- **Review:** None (instant)
- **Best for:** CI/CD, daily builds

### Closed Testing
- **Audience:** Unlimited (invited testers)
- **Review:** < 1 day typically
- **Best for:** Beta program, QA

### Open Testing
- **Audience:** Anyone with link
- **Review:** 1-7 days
- **Best for:** Public beta

### Production
- **Audience:** All users
- **Review:** 1-7 days
- **Best for:** Official releases
- **Rollout:** Staged (5% → 10% → 50% → 100%)

## Security Notes

**Service Account JSON:**
- 🔒 Contains sensitive credentials
- 🔒 Never commit to git
- 🔒 Store in password manager
- 🔒 Rotate keys annually
- 🔒 One per environment (dev/prod)

**Play Console Access:**
- Grant minimum required permissions
- Review access logs regularly
- Revoke unused accounts
- Use 2FA on Google account

## Troubleshooting

**"Cannot create service account"**
→ Check Google Cloud billing is enabled (API is free but billing must be linked)

**"Service account not appearing in Play Console"**
→ Wait 1-2 minutes, refresh page, clear browser cache

**"API enable button grayed out"**
→ Ensure correct project selected, check you have Owner/Editor role

**"Permission denied when testing API"**
→ Verify service account has "Release" permission in Play Console
→ Wait 5-10 minutes for permissions to propagate

**"404 - App not found"**
→ Create app in Play Console first
→ Verify package name matches exactly
→ Check service account has access to this specific app

## Integration with Other Skills

### Prerequisites:
- `android-release-build-setup` - Provides signing keystore

### Enables:
- `android-playstore-publishing` - Uses service account for deployment
- `android-playstore-pipeline` - Complete orchestrated workflow

## Validation

**Before proceeding to deployment, validate:**

```bash
# Install required Python packages
pip install google-auth google-api-python-client

# Run validation
python scripts/validate-playstore.py \
  ~/secure-location/service-account.json \
  com.example.yourapp
```

**Expected output:**
```
✅ Service account JSON is valid
✅ Successfully connected to Play Developer API
✅ Can access package: com.example.yourapp
✅ All validations passed!
```

## Common Mistakes

**❌ Using debug keystore for production**
→ Use production keystore from android-release-build-setup

**❌ Committing service-account.json**
→ Add to .gitignore, store securely

**❌ Insufficient permissions**
→ Service account needs "Release" permission minimum

**❌ Wrong package name**
→ Must match exactly (case-sensitive)

**❌ Not waiting for propagation**
→ Permissions can take 5-10 minutes to activate

## Skill Reference

This command uses the skill at:
`~/.claude/skills/user/devtools/android-playstore-setup/SKILL.md`

For detailed service account setup, API configuration, and troubleshooting, refer to the skill documentation.

## Related Commands

- `/devtools:android-release-setup` - Configure release builds (prerequisite)
- `/devtools:android-release-validate` - Validate before publishing
- `/devtools:android-playstore-publish` - Create deployment workflow (next)
- `/devtools:android-playstore-pipeline` - Complete setup (orchestration)

## Example Session

```
User: /devtools:android-playstore-setup

Claude: I'll help you set up Google Play Console integration.

First, let me verify your access...

Do you have a Google Play Developer account?
→ Yes

What is your app's package name?
→ com.example.myapp

Is your app already created in Play Console?
→ Yes

Perfect! Let's set up the service account...

=== Step 1: Create Service Account ===

I'll guide you through creating a service account in Google Cloud:

1. Open: https://console.cloud.google.com/
2. Create or select project
3. Navigate to: IAM & Admin → Service Accounts
4. Click "Create Service Account"
5. Name: playstore-deploy
6. Click through to create
7. Click ⋮ → Manage keys → Add Key → Create → JSON
8. Save the downloaded JSON file securely

Have you completed this step?
→ Yes

Great! What's the service account email?
→ playstore-deploy@myproject.iam.gserviceaccount.com

=== Step 2: Enable Play Developer API ===

[Detailed instructions...]

=== Step 3: Link to Play Console ===

[Detailed instructions...]

=== Step 4: Create Release Notes Structure ===

Creating directories...
✓ distribution/whatsnew/en-US/
✓ distribution/whatsnew/README.md

Which additional locales do you need?
→ de-DE, es-ES

✓ distribution/whatsnew/de-DE/
✓ distribution/whatsnew/es-ES/

=== Step 5: Validate Connection ===

Do you want to validate the API connection now?
→ Yes

Running validation...
✓ Service account JSON is valid
✓ API connection successful
✓ Can access package: com.example.myapp

=== Setup Complete! ===

✅ Service account configured
✅ API enabled and validated
✅ Release notes structure created
✅ Documentation generated

Next steps:
1. Add SERVICE_ACCOUNT_JSON to GitHub Secrets
2. Update release notes in distribution/whatsnew/
3. Run /devtools:android-playstore-publish

Files created:
- distribution/whatsnew/ (release notes)
- distribution/TRACKS.md (track workflow)
- distribution/GITHUB_SECRETS.md (secrets guide)
- scripts/validate-playstore.py (validation tool)
```

## Important Links

- Play Console: https://play.google.com/console/
- Google Cloud Console: https://console.cloud.google.com/
- API Library: https://console.cloud.google.com/apis/library
- Documentation: https://developers.google.com/android-publisher

## Notes

- Service account setup is one-time per project
- Permissions may take 5-10 minutes to propagate
- Store service account JSON very securely
- Test with validation script before deployment
- Review Play Console audit logs regularly
