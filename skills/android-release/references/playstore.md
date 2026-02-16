# Play Store Setup

## Prerequisites

1. Google Play Developer account ($25 one-time fee)
2. App created in Play Console
3. Service account with API access

## Service Account Setup

### 1. Create Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select or create project
3. IAM & Admin → Service Accounts → Create
4. Name: `play-store-deploy`
5. Skip optional steps, click Done

### 2. Generate Key

1. Click on the service account
2. Keys tab → Add Key → Create new key
3. Select JSON format
4. Download and store securely

### 3. Link to Play Console

1. Play Console → Setup → API access
2. Link your Google Cloud project
3. Find service account, click "Manage Play Console permissions"
4. Grant permissions:
   - View app information (required)
   - Release apps to testing tracks
   - Release to production (if needed)
   - Manage store presence (for metadata)
5. Apply permissions to your app(s)

## Release Tracks

| Track | Visibility | Use For |
|-------|------------|---------|
| Internal | Invite only (100 max) | Team testing |
| Closed | Invite only | External beta testers |
| Open | Anyone can join | Public beta |
| Production | Everyone | General availability |

## Track Promotion

Typical flow:
```
Internal → Closed (beta) → Production (staged) → Production (full)
```

## Staged Rollout

Production releases should use staged rollout:

```ruby
# Start at 10%
upload_to_play_store(
  track: "production",
  release_status: "inProgress",
  rollout: "0.1"
)

# Increase to 50%
upload_to_play_store(
  track: "production",
  release_status: "inProgress",
  rollout: "0.5",
  skip_upload_aab: true
)

# Full rollout
upload_to_play_store(
  track: "production",
  release_status: "completed",
  skip_upload_aab: true
)
```

## Store Listing Requirements

### Required Assets

| Asset | Size | Format |
|-------|------|--------|
| App icon | 512x512 | PNG |
| Feature graphic | 1024x500 | PNG/JPG |
| Phone screenshots | Min 2 | PNG/JPG |
| Privacy policy URL | - | HTTPS |

### Text Fields

| Field | Limit |
|-------|-------|
| Title | 50 chars |
| Short description | 80 chars |
| Full description | 4000 chars |

## Fastlane Metadata

Structure:
```
fastlane/metadata/android/
├── en-US/
│   ├── title.txt
│   ├── short_description.txt
│   ├── full_description.txt
│   ├── changelogs/
│   │   ├── default.txt
│   │   └── 123.txt  # Version code specific
│   └── images/
│       ├── icon.png
│       ├── featureGraphic.png
│       └── phoneScreenshots/
│           ├── 1.png
│           └── 2.png
└── de-DE/  # German
    └── ...
```

## Version Code Requirements

- Must be integer
- Must increase with each upload
- Different for each APK/AAB variant
- Formula: `major * 1000000 + minor * 1000 + patch`
  - Example: 1.2.3 → 1002003

## Common Issues

### "Version code already used"

Each upload must have higher version code:
```bash
./scripts/gradle-version.sh generate patch
```

### "APK/AAB must be signed"

Ensure signing config is applied:
```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

### "Permission denied"

Check service account has required permissions in Play Console.

### "App not found"

- Ensure package name matches exactly
- App must exist in Play Console (create manually first time)

## Internal App Sharing

For quick testing without Play Console review:

1. Play Console → Internal app sharing
2. Enable for your app
3. Upload APK directly
4. Share link with testers

Benefits:
- Instant availability (no review)
- Up to 100 testers
- Good for CI testing

## Useful Links

- [Play Console](https://play.google.com/console)
- [Google Cloud Console](https://console.cloud.google.com)
- [Fastlane Supply Docs](https://docs.fastlane.tools/actions/supply/)
