# Fastlane Setup for Android

## Prerequisites

- Ruby 3.3.x (NOT 3.4+ - incompatible with Fastlane)
- Android project with Gradle
- Play Store developer account
- Service account with API access

## Ruby Version Check

```bash
ruby --version
# Must be 3.3.x

# If 3.4+, use rbenv to install 3.3:
rbenv install 3.3.7
rbenv local 3.3.7
```

## Installation

### 1. Create Gemfile

```ruby
source "https://rubygems.org"

ruby "~> 3.3.0"

gem "fastlane", "~> 2.220"
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Create Directory Structure

```bash
mkdir -p fastlane
mkdir -p fastlane/metadata/android/en-US/images/phoneScreenshots
mkdir -p fastlane/metadata/android/en-US/changelogs
```

### 4. Create Appfile

`fastlane/Appfile`:

```ruby
json_key_file(ENV['PLAY_STORE_SERVICE_ACCOUNT'] || "service-account.json")
package_name("com.yourcompany.yourapp")
```

### 5. Create Fastfile

`fastlane/Fastfile`:

```ruby
default_platform(:android)

platform :android do
  # === Build ===
  
  desc "Build release bundle"
  lane :build_release do
    gradle(task: "clean")
    gradle(task: "bundleRelease")
  end

  # === Deploy ===

  desc "Deploy to internal track"
  lane :deploy_internal do
    build_release
    upload_to_play_store(
      track: "internal",
      release_status: "completed",
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Deploy to beta track"
  lane :deploy_beta do |options|
    build_release
    rollout = options[:rollout] || 1.0
    
    upload_to_play_store(
      track: "beta",
      release_status: rollout < 1.0 ? "inProgress" : "completed",
      rollout: rollout < 1.0 ? rollout.to_s : nil,
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Deploy to production track"
  lane :deploy_production do |options|
    build_release
    rollout = options[:rollout] || 0.1  # Default 10% for safety
    
    upload_to_play_store(
      track: "production",
      release_status: rollout < 1.0 ? "inProgress" : "completed",
      rollout: rollout < 1.0 ? rollout.to_s : nil,
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end

  # === Rollout Management ===

  desc "Increase rollout percentage"
  lane :increase_rollout do |options|
    rollout = options[:rollout] || 0.5
    
    upload_to_play_store(
      track: "production",
      release_status: rollout < 1.0 ? "inProgress" : "completed",
      rollout: rollout < 1.0 ? rollout.to_s : nil,
      skip_upload_aab: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end

  desc "Halt rollout"
  lane :halt_rollout do
    upload_to_play_store(
      track: "production",
      release_status: "halted",
      skip_upload_aab: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end

  # === Metadata ===

  desc "Upload metadata only"
  lane :upload_metadata do
    upload_to_play_store(
      skip_upload_aab: true,
      skip_upload_apk: true
    )
  end
end
```

## Service Account Setup

1. Go to Google Play Console → Setup → API access
2. Create new service account or link existing
3. Grant "Release manager" permission
4. Download JSON key file
5. Save as `service-account.json` (add to .gitignore)

For CI/CD, set as secret:
```bash
export PLAY_STORE_SERVICE_ACCOUNT=/path/to/service-account.json
```

## Metadata Structure

```
fastlane/metadata/android/en-US/
├── title.txt           # App name (50 chars)
├── short_description.txt  # Short desc (80 chars)
├── full_description.txt   # Full desc (4000 chars)
├── video.txt           # YouTube URL (optional)
├── changelogs/
│   └── default.txt     # Default changelog
└── images/
    ├── phoneScreenshots/
    │   ├── 1.png
    │   └── 2.png
    └── featureGraphic.png  # 1024x500
```

## Verification

```bash
# Check Fastlane installed
bundle exec fastlane --version

# List available lanes
bundle exec fastlane lanes

# Validate service account
bundle exec fastlane run validate_play_store_json_key
```

## Troubleshooting

### "Ruby 3.4 not compatible"

```bash
# Install Ruby 3.3 via rbenv
rbenv install 3.3.7
rbenv local 3.3.7
bundle install
```

### "Service account permission denied"

1. Check service account has "Release manager" role
2. Verify package name matches exactly
3. Ensure API access is enabled in Play Console

### "AAB not found"

```bash
# Build first
./gradlew bundleRelease

# Verify exists
ls app/build/outputs/bundle/release/
```
