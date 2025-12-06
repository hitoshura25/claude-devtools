---
name: android-playstore-setup
description: Setup Google Play Console integration for Android app deployment
category: android
version: 1.0.0
---

# Android Play Store Setup

This skill configures Google Play Console integration for automated app deployment. Sets up service account, API access, release notes structure, and track configuration.

## What This Does

1. **Service Account Creation**
   - Step-by-step guide for creating service account
   - Google Cloud Platform setup
   - Play Console permissions configuration
   - JSON key generation and download

2. **Play Developer API Setup**
   - Enable Google Play Developer API
   - Configure API access in Play Console
   - Link service account to Play Console
   - Validate API connectivity

3. **Release Notes Structure**
   - Create release notes directory
   - Set up locale-specific folders
   - Generate whatsnew file templates
   - Document release notes format

4. **Track Configuration**
   - Understand track types (internal, alpha, beta, production)
   - Configure testing tracks
   - Set up staged rollout options
   - Document track promotion workflow

5. **GitHub Secrets Documentation**
   - Document required secrets
   - Provide setup instructions
   - Generate secret values
   - Validate secret configuration

## Prerequisites

- Google Play Developer account ($25 one-time fee)
- App created in Play Console (or ready to create)
- Google Cloud Platform account
- Package name reserved in Play Console
- Admin access to Play Console

## Parameters

None required - skill will guide you through the interactive setup process.

## Step-by-Step Process

### Step 1: Verify Play Console Access

Check prerequisites:

**Ask the user:**
- "Do you have a Google Play Developer account?"
- "Is your app already created in Play Console?"
- "What is your app's package name?" (e.g., com.example.app)
- "Do you have admin access to the Play Console?"

**If no Play Console account:**
1. Guide to https://play.google.com/console/signup
2. Pay $25 one-time registration fee
3. Complete registration

**If app not created:**
1. Will create during setup
2. Or guide through manual creation

### Step 2: Create Service Account in Google Cloud

Interactive step-by-step guide:

```markdown
# Step 2.1: Access Google Cloud Console

1. Open: https://console.cloud.google.com/
2. Sign in with your Google account
3. Select or create a project
   - Project name: "Play Store Deployment" (or your app name)
   - Note: This can be the same project as Play Console or separate

# Step 2.2: Create Service Account

1. Navigate to: IAM & Admin → Service Accounts
   URL: https://console.cloud.google.com/iam-admin/serviceaccounts

2. Click "Create Service Account"

3. Fill in details:
   - Service account name: playstore-deploy
   - Service account ID: playstore-deploy (auto-filled)
   - Description: Service account for automated Play Store deployments
   
4. Click "Create and Continue"

5. Grant access (optional - skip for now)
   - Click "Continue" (we'll set permissions in Play Console)

6. Grant users access (optional - skip)
   - Click "Done"

# Step 2.3: Create JSON Key

1. Find your service account in the list
   - Look for: playstore-deploy@your-project.iam.gserviceaccount.com

2. Click the three dots (⋮) → "Manage keys"

3. Click "Add Key" → "Create new key"

4. Select "JSON" format

5. Click "Create"
   - A JSON file will download automatically
   - This file contains sensitive credentials!
   - Save it securely - you'll need it for GitHub Secrets

6. Rename the file: service-account.json
   - Store in secure location (NOT in git!)

⚠️ CRITICAL: This JSON key will only be shown once!
   - If lost, you'll need to create a new key
   - Never commit this file to version control
   - Store securely (password manager, encrypted storage)
```

**Capture from user:**
- Service account email (e.g., playstore-deploy@project.iam.gserviceaccount.com)
- JSON file location (for later GitHub Secrets setup)

### Step 3: Link Service Account to Play Console

```markdown
# Step 3.1: Navigate to API Access

1. Open Play Console: https://play.google.com/console/
2. Select your app (or "All apps" for account-level access)
3. In left sidebar: Setup → API access
   URL format: https://play.google.com/console/u/0/developers/{developer-id}/api-access

# Step 3.2: Link Google Cloud Project

If this is your first time:
1. You'll see "Link a Google Cloud project"
2. Click "Link a Google Cloud project"
3. Select your Google Cloud project from Step 2
4. Click "Link project"

If already linked:
1. You'll see "Google Cloud project linked"
2. Verify it's the correct project
3. Continue to next step

# Step 3.3: Grant Access to Service Account

1. Scroll to "Service accounts" section

2. Find your service account:
   - playstore-deploy@your-project.iam.gserviceaccount.com
   
3. Click "Grant access" (or "Manage Play Console permissions")

4. In the permissions dialog:
   Tab: App permissions
   - Select your app (or "All apps")
   
   Tab: Account permissions  
   - Select: "Release to production, exclude devices, and use Play App Signing"
   - Or select: "Admin (all permissions)" for full access
   
   Recommended for CI/CD:
   ☑ View app information and download bulk reports
   ☑ Release apps to testing tracks
   ☑ Release apps to production
   ☑ Manage testing tracks and edit tester lists
   
5. Click "Invite user"

6. Click "Send invite"

⚠️ IMPORTANT: Service account must have at least "Release to production" permission
   Otherwise automated deployment will fail.
```

### Step 4: Enable Play Developer API

```markdown
# Step 4.1: Navigate to API Library

1. Open: https://console.cloud.google.com/apis/library
2. Ensure correct project selected (from Step 2)

# Step 4.2: Search and Enable

1. Search for: "Google Play Android Developer API"
   
2. Click on the result (official Google API)

3. Click "Enable"
   - May take 1-2 minutes
   - Don't navigate away while enabling

4. Verify enabled:
   - Page should show "API enabled"
   - Green checkmark icon
   
# Step 4.3: Verify API Access

1. Go to: https://console.cloud.google.com/apis/dashboard
2. Verify "Google Play Android Developer API" is in enabled APIs list
3. Click on it to see API details
4. Note the "Quotas" tab (for future reference if hitting limits)
```

### Step 5: Create Release Notes Structure

Create directory structure for release notes:

```bash
# Create release notes directory
mkdir -p distribution/whatsnew

# Create locale-specific directories
cd distribution/whatsnew

# Common locales
mkdir -p en-US de-DE es-ES fr-FR it-IT ja-JP ko-KR pt-BR zh-CN zh-TW
```

**Create template files:**

`distribution/whatsnew/en-US/whatsnew`:
```
- Initial release
- Feature highlights go here
- Keep under 500 characters per Play Store guidelines
```

`distribution/whatsnew/README.md`:
```markdown
# Release Notes for Play Store

## Directory Structure

Each locale has its own directory with a `whatsnew` file:

```
distribution/whatsnew/
├── en-US/
│   └── whatsnew
├── de-DE/
│   └── whatsnew
├── es-ES/
│   └── whatsnew
└── ...
```

## File Format

- **Filename:** `whatsnew` (no extension)
- **Format:** Plain text
- **Max length:** 500 characters
- **Encoding:** UTF-8

## Content Guidelines

- Highlight new features and improvements
- Use bullet points for clarity
- Mention bug fixes if significant
- Keep language simple and user-friendly
- Test that it fits in 500 characters

## Example

```
- New: Dark mode support
- Improved: Faster app startup
- Fixed: Crash when uploading photos
- Updated: Refreshed user interface
```

## Supported Locales

Common Play Store locales:
- en-US (English - US)
- en-GB (English - UK)
- de-DE (German)
- es-ES (Spanish)
- fr-FR (French)
- it-IT (Italian)
- ja-JP (Japanese)
- ko-KR (Korean)
- pt-BR (Portuguese - Brazil)
- ru-RU (Russian)
- zh-CN (Chinese - Simplified)
- zh-TW (Chinese - Traditional)

Add more locales as needed for your target markets.

## Updating Release Notes

1. Edit the `whatsnew` file for each locale
2. Keep content under 500 characters
3. Commit changes before release
4. GitHub Actions will automatically include them in deployment
```

**Ask user:**
- "Which locales do you need? (default: en-US only)"
- Create directories for selected locales

### Step 6: Configure Release Tracks

Document track types and workflow:

Create `distribution/TRACKS.md`:

```markdown
# Play Store Release Tracks

## Track Types

### 1. Internal Testing
- **Purpose:** Team and internal testers only
- **Audience:** Up to 100 testers
- **Review:** None (instant availability)
- **Rollout:** Immediate (100%)
- **Use case:** Daily builds, QA testing

**Setup:**
1. Play Console → Testing → Internal testing
2. Create email list of internal testers
3. Share opt-in URL with team

### 2. Closed Testing (Alpha)
- **Purpose:** Limited external testing
- **Audience:** Selected testers (via email list or Google Groups)
- **Review:** Minimal (< 1 day typically)
- **Rollout:** Immediate to testers
- **Use case:** Beta testers, early adopters

**Setup:**
1. Play Console → Testing → Closed testing
2. Create testing track (e.g., "alpha")
3. Add testers via email list or Google Groups
4. Share opt-in URL

### 3. Open Testing (Beta)
- **Purpose:** Public beta
- **Audience:** Anyone with opt-in link (up to limit)
- **Review:** Standard review (1-7 days)
- **Rollout:** Configurable (staged or full)
- **Use case:** Public beta program

**Setup:**
1. Play Console → Testing → Open testing
2. Configure countries
3. Set maximum testers (optional)
4. Publish opt-in URL publicly

### 4. Production
- **Purpose:** Public release
- **Audience:** All users
- **Review:** Standard review (1-7 days, can be longer)
- **Rollout:** Configurable (staged recommended)
- **Use case:** Final public release

**Staged Rollout:**
- Day 1: 5% of users
- Day 2: 10% (if no critical issues)
- Day 3: 20%
- Day 4: 50%
- Day 5: 100%

Can halt rollout if issues detected.

## Recommended Workflow

```
Development → Internal (continuous)
              ↓
              Closed/Alpha (weekly)
              ↓
              Open/Beta (bi-weekly)
              ↓
              Production (monthly)
```

## Track Promotion

Promote releases between tracks:

1. Internal → Alpha: Manual promotion or automated
2. Alpha → Beta: After QA approval
3. Beta → Production: After successful beta period

**Promotion in Play Console:**
1. Go to Release → [Track] → Releases
2. Find release to promote
3. Click "Promote release"
4. Select target track
5. Update release notes if needed
6. Submit for review

## Version Code Strategy

Each track can have different version codes:

- Internal: 100X (e.g., 1001, 1002, 1003)
- Alpha: 200X (e.g., 2001, 2002)
- Beta: 300X (e.g., 3001, 3002)  
- Production: X (e.g., 1, 2, 3)

Or use continuous version codes (simpler):
- All tracks: Sequential (1, 2, 3, 4, ...)

Version code MUST increase with each upload.
```

### Step 7: Document GitHub Secrets Setup

Create `distribution/GITHUB_SECRETS.md`:

```markdown
# GitHub Secrets Setup for Play Store Deployment

## Required Secrets

Navigate to: Your Repository → Settings → Secrets and variables → Actions

### 1. SERVICE_ACCOUNT_JSON

**Description:** Contents of the service account JSON file from Step 2.3

**How to get value:**
1. Open the JSON file downloaded in Step 2.3
2. Copy the ENTIRE contents
3. Paste as secret value

**Example format (do not use this, use your actual file):**
```json
{
  "type": "service_account",
  "project_id": "your-project",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "playstore-deploy@your-project.iam.gserviceaccount.com",
  ...
}
```

**Verification:**
- File starts with `{` and ends with `}`
- Contains "type": "service_account"
- Contains "client_email" with your service account email
- Contains "private_key" section

### 2. Signing Secrets (if not already set)

If you haven't set up signing secrets from android-release-build-setup:

**SIGNING_KEY_STORE_BASE64**
- Base64-encoded production keystore
- Get from: `base64 -w 0 keystores/production-release.jks`

**SIGNING_KEY_ALIAS**  
- Keystore alias (usually "upload")

**SIGNING_STORE_PASSWORD**
- Keystore password

**SIGNING_KEY_PASSWORD**
- Key password

See `keystores/KEYSTORE_INFO.txt` for values.

## Verification

After adding secrets, verify:

1. All 5 secrets are listed (1 service account + 4 signing)
2. No typos in secret names
3. Values are not truncated
4. SERVICE_ACCOUNT_JSON is valid JSON

## Security Notes

- Never commit these values to git
- Never log secret values in workflows
- Rotate service account keys periodically
- Use separate service accounts for different environments if needed
- Monitor API usage in Google Cloud Console
```

### Step 8: Validate Play Store Connection

Create validation script:

```python
# validate-playstore.py
"""
Validate Google Play Store API connection.
This script tests that the service account has proper access.
"""

import sys
import json
from pathlib import Path

def validate_service_account_json(json_path):
    """Validate service account JSON file."""
    print("Validating service account JSON...")
    
    try:
        with open(json_path) as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"❌ File not found: {json_path}")
        return False
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON: {e}")
        return False
    
    # Check required fields
    required_fields = [
        "type",
        "project_id", 
        "private_key_id",
        "private_key",
        "client_email",
        "client_id"
    ]
    
    for field in required_fields:
        if field not in data:
            print(f"❌ Missing required field: {field}")
            return False
    
    # Validate type
    if data["type"] != "service_account":
        print(f"❌ Invalid type: {data['type']} (expected 'service_account')")
        return False
    
    # Validate email format
    email = data["client_email"]
    if not email.endswith(".iam.gserviceaccount.com"):
        print(f"⚠️  Warning: Unexpected email format: {email}")
    
    print(f"✅ Service account JSON is valid")
    print(f"   Email: {email}")
    print(f"   Project: {data['project_id']}")
    
    return True

def test_api_connection(json_path, package_name):
    """Test connection to Play Developer API."""
    print(f"\nTesting API connection for package: {package_name}...")
    
    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
    except ImportError:
        print("❌ Required packages not installed")
        print("   Install: pip install google-auth google-api-python-client")
        return False
    
    try:
        # Authenticate
        credentials = service_account.Credentials.from_service_account_file(
            json_path,
            scopes=['https://www.googleapis.com/auth/androidpublisher']
        )
        
        # Build service
        service = build('androidpublisher', 'v3', credentials=credentials)
        
        # Try to create an edit (read-only operation)
        edit_request = service.edits().insert(body={}, packageName=package_name)
        edit_result = edit_request.execute()
        edit_id = edit_result['id']
        
        print(f"✅ Successfully connected to Play Developer API")
        print(f"   Can access package: {package_name}")
        
        # Clean up edit
        service.edits().delete(packageName=package_name, editId=edit_id).execute()
        
        # Get tracks
        tracks_response = service.edits().tracks().list(
            packageName=package_name,
            editId=edit_id
        ).execute()
        
        tracks = [track['track'] for track in tracks_response.get('tracks', [])]
        if tracks:
            print(f"   Available tracks: {', '.join(tracks)}")
        else:
            print(f"   No releases yet (expected for new apps)")
        
        return True
        
    except Exception as e:
        print(f"❌ API connection failed: {e}")
        
        if "404" in str(e):
            print("   → App not found in Play Console")
            print("   → Verify package name is correct")
            print("   → Create app in Play Console first")
        elif "403" in str(e):
            print("   → Permission denied")
            print("   → Verify service account has 'Release' permissions")
            print("   → Check service account is linked in Play Console")
        elif "401" in str(e):
            print("   → Authentication failed")
            print("   → Verify service account JSON is correct")
        
        return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python validate-playstore.py <service-account.json> <package-name>")
        print("Example: python validate-playstore.py service-account.json com.example.app")
        sys.exit(1)
    
    json_path = sys.argv[1]
    package_name = sys.argv[2]
    
    print("=" * 60)
    print("Play Store API Validation")
    print("=" * 60)
    print()
    
    # Validate JSON
    if not validate_service_account_json(json_path):
        sys.exit(1)
    
    # Test API connection
    if not test_api_connection(json_path, package_name):
        sys.exit(1)
    
    print()
    print("=" * 60)
    print("✅ All validations passed!")
    print("=" * 60)
    print()
    print("Next steps:")
    print("1. Add SERVICE_ACCOUNT_JSON to GitHub Secrets")
    print("2. Run android-playstore-publishing skill")
    print("3. Deploy your app!")
```

**Ask user:**
- "Do you want to validate API connection now?"
- If yes: Run validation script with service account JSON and package name

### Step 9: Validate Play Console Access (MANDATORY)

**CRITICAL: This step is MANDATORY and must pass before completing the skill.**

Validate the setup actually works:

```bash
# 1. REQUIRED: Validate service account JSON format
python3 scripts/validate-playstore.py path/to/service-account.json

# 2. REQUIRED: Test API connection
python3 scripts/validate-playstore.py path/to/service-account.json com.example.app

# 3. REQUIRED: Verify package access
# Should output: ✓ Can access package: com.example.app
```

**Expected output:**
- JSON valid: ✓ "Service account JSON is valid"
- API connection: ✓ "Successfully connected to Play Developer API"
- Package access: ✓ "Can access package: com.example.app"

**If ANY fail:**
1. DO NOT complete skill
2. Check error message:
   - 404 → App not created in Play Console yet
   - 403 → Service account lacks permissions
   - 401 → JSON key invalid
3. Fix in Play Console
4. Re-run validation
5. Only complete when ALL pass

**Common Failures:**
- "Package not found (404)" → Create app in Play Console first
- "Permission denied (403)" → Grant "Release" permission to service account
- "Invalid credentials (401)" → Re-download service account JSON
- "API not enabled" → Enable Play Developer API in Google Cloud

### Step 10: Generate Setup Summary

```
✅ Android Play Store Setup Complete!

🔑 Service Account Created:
  Email: playstore-deploy@your-project.iam.gserviceaccount.com
  JSON Key: service-account.json (stored securely)
  Permissions: Release to production ✓
  API Access: Enabled ✓

📱 Play Console Configuration:
  App: {APP_NAME}
  Package: {PACKAGE_NAME}
  Service Account: Linked ✓
  API: Google Play Android Developer API ✓

📝 Release Notes Structure:
  Directory: distribution/whatsnew/
  Locales: {LOCALE_LIST}
  Format: Plain text, max 500 chars
  Template: Created ✓

📊 Release Tracks Configured:
  Internal: For team testing
  Alpha: For beta testers
  Beta: For public beta
  Production: For public release
  Documentation: distribution/TRACKS.md ✓

🔒 GitHub Secrets Documented:
  Required secrets: 5 total
  SERVICE_ACCOUNT_JSON: Ready to add
  Signing secrets: Already configured
  Instructions: distribution/GITHUB_SECRETS.md ✓

✓ API Connection: Validated successfully

📋 Next Steps:

  1. Add GitHub Secrets:
     - Go to: Repository → Settings → Secrets → Actions
     - Add: SERVICE_ACCOUNT_JSON
     - Copy entire contents of service-account.json
     - Verify: No typos, complete JSON
  
  2. Secure Service Account JSON:
     - Store in password manager
     - Back up to secure location
     - NEVER commit to git
     - Consider: ~/.play-store-keys/ (gitignored location)
  
  3. Update Release Notes:
     - Edit: distribution/whatsnew/en-US/whatsnew
     - Add: Your app's features
     - Translate: For other locales if needed
  
  4. Create First Release:
     - Use: android-playstore-publishing skill
     - Or: Manual upload to internal track for testing
  
  5. Test Deployment:
     - Deploy to internal track first
     - Verify on test device
     - Then promote to other tracks

⚠️  Important Security Reminders:
  - Service account JSON contains sensitive credentials
  - Never commit to version control
  - Rotate keys periodically (annually recommended)
  - Monitor API usage in Google Cloud Console
  - Review Play Console audit logs regularly

🔗 Important Links:
  - Play Console: https://play.google.com/console/
  - Google Cloud Console: https://console.cloud.google.com/
  - API Dashboard: https://console.cloud.google.com/apis/dashboard
  - Documentation: https://developers.google.com/android-publisher
```

## Error Handling

### Service Account Creation Fails

**"Project not found"**
- Ensure you're signed in with correct Google account
- Verify project was created successfully
- Check project selector in Google Cloud Console

**"Permission denied"**
- Need Owner or Editor role on Google Cloud project
- Ask project owner to grant access

### Play Console Linking Fails

**"Service account not found"**
- Wait 1-2 minutes after creating service account
- Refresh Play Console page
- Verify service account email is correct

**"Cannot grant access"**
- Need Admin permissions in Play Console
- Ask Play Console admin for help

### API Enable Fails

**"API not found"**
- Search for exact name: "Google Play Android Developer API"
- Ensure correct project selected
- Try direct link: https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com

**"Billing not enabled"**
- API is free but Google Cloud requires billing account linked
- Link billing account (won't be charged for this API)

### API Validation Fails

**404 - App not found:**
- App must be created in Play Console first
- Package name must match exactly
- App must have at least one draft or published release

**403 - Permission denied:**
- Service account needs "Release" permission minimum
- Re-check permissions in Play Console → API access
- Wait 5-10 minutes for permissions to propagate

**401 - Authentication failed:**
- Service account JSON is incorrect
- Download new JSON key
- Verify JSON is valid (not corrupted)

## Security Best Practices

1. **Service Account JSON**
   - Store in secure password manager
   - Never commit to git (add to .gitignore)
   - Rotate keys annually
   - Use separate accounts for dev/prod if needed

2. **Minimal Permissions**
   - Grant only required permissions
   - Don't use "Admin (all permissions)" unless necessary
   - Review permissions periodically

3. **API Key Rotation**
   - Rotate annually or when employee leaves
   - Update GitHub Secrets after rotation
   - Test deployment after rotation

4. **Audit Logs**
   - Review Play Console audit logs monthly
   - Check for unauthorized access
   - Monitor API usage in Google Cloud

5. **Backup**
   - Back up service account JSON securely
   - Document setup process
   - Store credentials in company vault

## Integration with Other Skills

This skill integrates with:
- `android-release-build-setup` - Provides signing configuration
- `android-release-validation` - Validates builds before upload
- `android-playstore-publishing` - Uses service account for deployment
- `android-playstore-pipeline` - Part of complete workflow

## Troubleshooting

### "Cannot create service account"
Check:
- Google Cloud billing enabled
- Correct permissions in Google Cloud
- Project quota not exceeded

### "Service account not appearing in Play Console"
Wait:
- Can take 1-2 minutes to sync
- Refresh Play Console page
- Clear browser cache if needed

### "API quota exceeded"
- Play Developer API has generous quotas
- Check quota usage in Google Cloud Console
- Contact Google Cloud support if legitimate need

### "Validation script fails"
Install required packages:
```bash
pip install google-auth google-api-python-client
```

## Files Created/Modified

**Created:**
- `distribution/whatsnew/en-US/whatsnew` - Release notes template
- `distribution/whatsnew/README.md` - Release notes documentation  
- `distribution/TRACKS.md` - Track configuration guide
- `distribution/GITHUB_SECRETS.md` - Secrets setup guide
- `scripts/validate-playstore.py` - API validation script
- `service-account.json` - Service account key (DO NOT COMMIT!)

**Modified:**
- `.gitignore` - Add service-account.json and distribution/secrets/

**Downloaded:**
- Service account JSON key from Google Cloud

## Completion Criteria (ALL MUST PASS)

Do NOT mark this skill as complete unless ALL of the following are verified:

✅ **Service account created**
  - [ ] Service account exists in Google Cloud
  - [ ] JSON key downloaded
  - [ ] Service account email documented

✅ **Play Developer API enabled**
  - [ ] API enabled in Google Cloud Console
  - [ ] Service account has API access

✅ **Play Console integration**
  - [ ] Service account linked to Play Console
  - [ ] "Release" permission granted
  - [ ] Access to specific app package granted

✅ **MANDATORY: API validation**
  - [ ] `validate-playstore.py` script exists
  - [ ] Service account JSON validates successfully
  - [ ] API connection test succeeds
  - [ ] Can access target package (no 404/403 errors)

✅ **Release notes structure**
  - [ ] distribution/whatsnew/ directory exists
  - [ ] At least en-US locale created
  - [ ] README.md with guidelines created

✅ **Documentation created**
  - [ ] GITHUB_SECRETS.md created
  - [ ] TRACKS.md created
  - [ ] PLAY_CONSOLE_SETUP.md created (optional but recommended)

**If ANY checkbox is unchecked, the skill is NOT complete.**

## Expected Outcomes

After running this skill:

✅ **Service account created** and configured in Google Cloud
✅ **Play Console linked** with proper permissions
✅ **API enabled** and validated
✅ **Release notes structure** created
✅ **Track workflow** documented
✅ **GitHub Secrets** documented
✅ **Ready for deployment** with android-playstore-publishing skill

## Next Skills (Dependencies)

This skill DEPENDS on:
- `android-release-build-setup` - Must complete first (uses signing keystore info)

This skill is a PREREQUISITE for:
- `android-playstore-publishing` - Uses service account for deployment
- `android-playstore-pipeline` - Part of complete workflow

Do NOT run this skill until `android-release-build-setup` completion criteria are met.
Do NOT run publishing skills until this skill's completion criteria are met.

## References

- [Play Console Help](https://support.google.com/googleplay/android-developer)
- [Service Accounts](https://cloud.google.com/iam/docs/service-accounts)
- [Play Developer API](https://developers.google.com/android-publisher)
- [Release Notes Guidelines](https://support.google.com/googleplay/android-developer/answer/7159011)
