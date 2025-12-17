# Fastlane Store Assets Implementation Spec

**Purpose:** Replace GPP-based deployment with Fastlane, add screenshot automation, and integrate IconKitchen for app icons
**Date:** 2025-12-15
**Status:** Ready for Implementation

---

## Overview

This spec consolidates Play Store deployment around Fastlane, which provides:
- Screenshot automation via `screengrab`
- Full metadata management via `supply`
- Unified tooling for the entire release process

**Key Decision:** Fastlane replaces Gradle Play Publisher (GPP) as the deployment mechanism.

---

## Skills to Create/Update

| Skill | Action | Description |
|-------|--------|-------------|
| `android-fastlane-setup` | **CREATE** | Core Fastlane configuration |
| `android-screenshot-automation` | **CREATE** | Screengrab integration with existing e2e tests |
| `android-app-icon` | **CREATE** | IconKitchen workflow + asset placement |
| `android-store-listing` | **CREATE** | Feature graphic + metadata templates |
| `android-playstore-setup` | **UPDATE** | Orchestrate Fastlane-based setup |
| `android-workflow-internal` | **UPDATE** | Use Fastlane instead of GPP |
| `android-workflow-beta` | **UPDATE** | Use Fastlane instead of GPP |
| `android-workflow-production` | **UPDATE** | Use Fastlane instead of GPP |

---

## Part 1: android-fastlane-setup

### Purpose
Setup Fastlane with `supply` for Play Store deployment.

### Location
`skills/android-fastlane-setup/SKILL.md`

### Inputs
| Input | Required | Description |
|-------|----------|-------------|
| package_name | Yes | Android app package name |
| service_account_path | Yes | Path to service account JSON |

### Outputs
| Output | Location |
|--------|----------|
| Gemfile | `./Gemfile` |
| Appfile | `./fastlane/Appfile` |
| Fastfile | `./fastlane/Fastfile` |
| Screengrabfile | `./fastlane/Screengrabfile` |
| Metadata structure | `./fastlane/metadata/android/` |

### Process

#### Step 1: Check Ruby Installation

```bash
# Check if Ruby is installed
ruby --version || echo "Ruby not found. Please install Ruby 2.7+ first."

# Check if Bundler is installed
gem install bundler --no-document
```

#### Step 2: Create Gemfile

Create `./Gemfile`:

```ruby
source "https://rubygems.org"

gem "fastlane"
gem "screengrab"
```

#### Step 3: Install Dependencies

```bash
bundle install
```

#### Step 4: Create Fastlane Directory Structure

```bash
mkdir -p fastlane
mkdir -p fastlane/metadata/android/en-US/images/phoneScreenshots
mkdir -p fastlane/metadata/android/en-US/images/sevenInchScreenshots
mkdir -p fastlane/metadata/android/en-US/images/tenInchScreenshots
```

#### Step 5: Create Appfile

Create `./fastlane/Appfile`:

```ruby
# Path to service account JSON for Play Store API
json_key_file(ENV['PLAY_STORE_SERVICE_ACCOUNT'] || "path/to/service-account.json")

# Your app's package name
package_name("${PACKAGE_NAME}")
```

#### Step 6: Create Fastfile

Create `./fastlane/Fastfile`:

```ruby
default_platform(:android)

platform :android do
  # ============================================
  # Build Lanes
  # ============================================

  desc "Build debug APK and test APK for screenshots"
  lane :build_for_screenshots do
    gradle(task: "clean")
    gradle(task: "assembleDebug")
    gradle(task: "assembleAndroidTest")
  end

  desc "Build release bundle"
  lane :build_release do
    gradle(task: "clean")
    gradle(task: "bundleRelease")
  end

  # ============================================
  # Screenshot Lane
  # ============================================

  desc "Capture screenshots for Play Store"
  lane :screenshots do
    build_for_screenshots
    capture_android_screenshots
  end

  # ============================================
  # Deployment Lanes
  # ============================================

  desc "Deploy to internal testing track"
  lane :deploy_internal do
    build_release
    upload_to_play_store(
      track: "internal",
      release_status: "completed",
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Deploy to beta/closed testing track"
  lane :deploy_beta do |options|
    build_release
    
    # Support staged rollout
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
    
    # Default to 10% staged rollout for safety
    rollout = options[:rollout] || 0.1
    
    upload_to_play_store(
      track: "production",
      release_status: rollout < 1.0 ? "inProgress" : "completed",
      rollout: rollout < 1.0 ? rollout.to_s : nil,
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Increase production rollout percentage"
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

  desc "Halt production rollout"
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

  # ============================================
  # Metadata Lanes
  # ============================================

  desc "Upload metadata only (no APK/AAB)"
  lane :upload_metadata do
    upload_to_play_store(
      skip_upload_aab: true,
      skip_upload_apk: true
    )
  end

  desc "Upload screenshots only"
  lane :upload_screenshots do
    upload_to_play_store(
      skip_upload_aab: true,
      skip_upload_apk: true,
      skip_upload_metadata: true
    )
  end

  # ============================================
  # Version Management
  # ============================================

  desc "Get current version from version.properties"
  lane :get_version do
    version_file = "../version.properties"
    if File.exist?(version_file)
      props = {}
      File.readlines(version_file).each do |line|
        key, value = line.strip.split("=")
        props[key] = value if key && value
      end
      UI.message("Version: #{props['VERSION_NAME']} (#{props['VERSION_CODE']})")
      props
    else
      UI.user_error!("version.properties not found. Run /devtools:version-management first.")
    end
  end

  # ============================================
  # Full Release Workflows
  # ============================================

  desc "Full internal release: screenshots + build + deploy"
  lane :release_internal do
    screenshots
    deploy_internal
  end

  desc "Full beta release: build + deploy"
  lane :release_beta do |options|
    deploy_beta(rollout: options[:rollout])
  end

  desc "Full production release: build + deploy with staged rollout"
  lane :release_production do |options|
    deploy_production(rollout: options[:rollout])
  end
end
```

#### Step 7: Create Screengrabfile

Create `./fastlane/Screengrabfile`:

```ruby
# App package name
app_package_name("${PACKAGE_NAME}")

# Test instrumentation runner (AndroidX)
test_instrumentation_runner("androidx.test.runner.AndroidJUnitRunner")

# APK paths
app_apk_path("app/build/outputs/apk/debug/app-debug.apk")
tests_apk_path("app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk")

# Locales to capture (add more as needed)
locales(["en-US"])

# Output directory (matches supply's expected structure)
output_directory("fastlane/metadata/android")

# Clear old screenshots
clear_previous_screenshots(true)

# Use specific test class for screenshots
use_tests_in_classes(["${PACKAGE_NAME}.screenshots.ScreenshotTest"])

# Launch arguments (optional)
# launch_arguments([
#   "screenshot_mode true"
# ])

# Ending locale (restore device to this locale after)
ending_locale("en-US")

# Skip open summary (for CI)
# skip_open_summary(true)

# Device type (defaults to phone)
# device_type("phone")
```

#### Step 8: Create Metadata Templates

Create `./fastlane/metadata/android/en-US/title.txt`:
```
${APP_NAME}
```

Create `./fastlane/metadata/android/en-US/short_description.txt`:
```
${SHORT_DESCRIPTION}
```

Create `./fastlane/metadata/android/en-US/full_description.txt`:
```
${FULL_DESCRIPTION}

Features:
• Feature 1
• Feature 2
• Feature 3

For more information, visit our website.
```

Create `./fastlane/metadata/android/en-US/changelogs/default.txt`:
```
• Bug fixes and performance improvements
```

Create `./fastlane/metadata/android/en-US/video.txt`:
```
```
(Empty file - add YouTube URL if you have a promo video)

#### Step 9: Update .gitignore

Append to `.gitignore`:

```gitignore
# Fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots
fastlane/test_output
fastlane/readme.md
vendor/bundle

# Don't ignore metadata (we want to track store listing)
!fastlane/metadata/
```

### Verification

```bash
# Verify Fastlane installed
bundle exec fastlane --version

# Verify lanes are available
bundle exec fastlane lanes

# Test service account connection
bundle exec fastlane run validate_play_store_json_key
```

### Completion Criteria

- [ ] `Gemfile` exists with fastlane and screengrab
- [ ] `bundle install` succeeds
- [ ] `fastlane/Appfile` configured with package name
- [ ] `fastlane/Fastfile` has all lanes
- [ ] `fastlane/Screengrabfile` configured
- [ ] Metadata directory structure created
- [ ] `bundle exec fastlane lanes` shows all lanes

---

## Part 2: android-screenshot-automation

### Purpose
Setup automated screenshot capture using Fastlane Screengrab, integrating with existing e2e test infrastructure.

### Location
`skills/android-screenshot-automation/SKILL.md`

### Prerequisites
- `android-fastlane-setup` completed
- `android-e2e-testing-setup` completed (UI Automator tests exist)

### Inputs
| Input | Required | Description |
|-------|----------|-------------|
| screens | Yes | List of screens to capture |
| locales | No | Locales to capture (default: en-US) |

### Outputs
| Output | Location |
|--------|----------|
| Screenshot test class | `app/src/androidTest/.../screenshots/ScreenshotTest.kt` |
| Debug manifest permissions | `app/src/debug/AndroidManifest.xml` |
| Screenshots | `fastlane/metadata/android/{locale}/images/phoneScreenshots/` |

### Process

#### Step 1: Add Screengrab Dependency

Add to `app/build.gradle.kts`:

```kotlin
dependencies {
    // Existing test dependencies...
    
    // Screengrab for automated screenshots
    androidTestImplementation("tools.fastlane:screengrab:2.1.1")
}
```

#### Step 2: Create Debug Manifest

Create or update `app/src/debug/AndroidManifest.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Screengrab permissions -->
    
    <!-- Store screenshots on external storage (API <= 18) -->
    <uses-permission 
        android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="18" />
    
    <!-- Change device locale during tests -->
    <uses-permission 
        android:name="android.permission.CHANGE_CONFIGURATION"
        tools:ignore="ProtectedPermissions" />
    
    <!-- Enable demo mode for clean status bar -->
    <uses-permission 
        android:name="android.permission.DUMP"
        tools:ignore="ProtectedPermissions" />

</manifest>
```

#### Step 3: Create Demo Mode Helper (Optional but Recommended)

Create `app/src/androidTest/.../screenshots/DemoModeRule.kt`:

```kotlin
package ${PACKAGE_NAME}.screenshots

import android.os.ParcelFileDescriptor
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.rules.TestRule
import org.junit.runner.Description
import org.junit.runners.model.Statement
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * JUnit Rule that enables Android Demo Mode for clean status bar screenshots.
 * 
 * Demo mode shows:
 * - Full battery (100%)
 * - Full signal strength
 * - Fixed time (12:00)
 * - No notifications
 */
class DemoModeRule : TestRule {
    
    override fun apply(base: Statement, description: Description): Statement {
        return object : Statement() {
            override fun evaluate() {
                enableDemoMode()
                try {
                    base.evaluate()
                } finally {
                    disableDemoMode()
                }
            }
        }
    }
    
    private fun enableDemoMode() {
        executeShellCommand("settings put global sysui_demo_allowed 1")
        executeShellCommand("am broadcast -a com.android.systemui.demo -e command enter")
        executeShellCommand("am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200")
        executeShellCommand("am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false")
        executeShellCommand("am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4")
        executeShellCommand("am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4")
        executeShellCommand("am broadcast -a com.android.systemui.demo -e command notifications -e visible false")
    }
    
    private fun disableDemoMode() {
        executeShellCommand("am broadcast -a com.android.systemui.demo -e command exit")
    }
    
    private fun executeShellCommand(command: String) {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val automation = instrumentation.uiAutomation
        
        val pfd: ParcelFileDescriptor = automation.executeShellCommand(command)
        val reader = BufferedReader(InputStreamReader(ParcelFileDescriptor.AutoCloseInputStream(pfd)))
        reader.readLines() // Consume output
        reader.close()
    }
}
```

#### Step 4: Create Screenshot Test Class

Create `app/src/androidTest/.../screenshots/ScreenshotTest.kt`:

```kotlin
package ${PACKAGE_NAME}.screenshots

import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.matcher.ViewMatchers.withId
import org.junit.Before
import org.junit.ClassRule
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith
import tools.fastlane.screengrab.Screengrab
import tools.fastlane.screengrab.UiAutomatorScreenshotStrategy
import tools.fastlane.screengrab.locale.LocaleTestRule

import ${PACKAGE_NAME}.R
import ${PACKAGE_NAME}.MainActivity

/**
 * Automated screenshot capture for Play Store listing.
 * 
 * Run with: bundle exec fastlane screenshots
 * 
 * Screenshots are saved to: fastlane/metadata/android/{locale}/images/phoneScreenshots/
 */
@RunWith(AndroidJUnit4::class)
class ScreenshotTest {

    companion object {
        // Automatically switches device locale between test runs
        @get:ClassRule
        @JvmField
        val localeTestRule = LocaleTestRule()
    }

    // Launch main activity for each test
    @get:Rule
    val activityRule = ActivityScenarioRule(MainActivity::class.java)
    
    // Enable demo mode for clean status bar (optional)
    @get:Rule
    val demoModeRule = DemoModeRule()

    @Before
    fun setup() {
        // Use UI Automator strategy for better screenshots
        // This captures dialogs, shadows, and system UI correctly
        Screengrab.setDefaultScreenshotStrategy(UiAutomatorScreenshotStrategy())
    }

    @Test
    fun captureScreenshots() {
        // Wait for app to fully load
        Thread.sleep(1000)
        
        // Screenshot 1: Main/Home screen
        Screengrab.screenshot("01_home")

        // TODO: Navigate to next screen and capture
        // Example:
        // onView(withId(R.id.settings_button)).perform(click())
        // Thread.sleep(500)
        // Screengrab.screenshot("02_settings")
        
        // TODO: Add more screenshots as needed
        // Recommendation: Capture 4-8 key screens that showcase your app's features
    }
    
    // Optional: Separate test methods for different flows
    // This helps organize screenshots and makes debugging easier
    
    @Test
    fun captureOnboardingFlow() {
        // If your app has onboarding, capture those screens
        // Screengrab.screenshot("onboarding_01_welcome")
        // onView(withId(R.id.next_button)).perform(click())
        // Screengrab.screenshot("onboarding_02_features")
    }
}
```

#### Step 5: Update Screengrabfile

Update `./fastlane/Screengrabfile` with the correct test class:

```ruby
# Use the screenshot test class
use_tests_in_classes(["${PACKAGE_NAME}.screenshots.ScreenshotTest"])
```

#### Step 6: Run Screenshots

```bash
# Build and capture screenshots
bundle exec fastlane screenshots

# Or run screengrab directly
bundle exec fastlane run capture_android_screenshots
```

### Adding Multiple Device Sizes

For tablet screenshots, update `Screengrabfile`:

```ruby
# For multiple device types, run screengrab multiple times
# with different emulators

# Phone screenshots (default)
device_type("phone")

# To capture tablet screenshots:
# 1. Start a tablet emulator (Nexus 7 or Nexus 10)
# 2. Run: bundle exec screengrab --device_type sevenInch
# 3. Run: bundle exec screengrab --device_type tenInch
```

Or create a lane that runs all device types:

```ruby
# Add to Fastfile
desc "Capture screenshots for all device types"
lane :screenshots_all_devices do
  # Phone screenshots
  capture_android_screenshots(device_type: "phone")
  
  # 7-inch tablet (requires tablet emulator running)
  # capture_android_screenshots(device_type: "sevenInch")
  
  # 10-inch tablet (requires tablet emulator running)
  # capture_android_screenshots(device_type: "tenInch")
end
```

### Verification

```bash
# Build APKs
./gradlew assembleDebug assembleAndroidTest

# Run screenshots (with emulator running)
bundle exec fastlane screenshots

# Check output
ls -la fastlane/metadata/android/en-US/images/phoneScreenshots/
```

### Completion Criteria

- [ ] `tools.fastlane:screengrab` dependency added
- [ ] Debug manifest has required permissions
- [ ] `ScreenshotTest.kt` exists with at least one screenshot
- [ ] `DemoModeRule.kt` created for clean status bar
- [ ] `bundle exec fastlane screenshots` runs successfully
- [ ] Screenshots appear in `fastlane/metadata/android/en-US/images/phoneScreenshots/`

---

## Part 3: android-app-icon

### Purpose
Guide user through IconKitchen to generate app icons, then place assets in correct locations.

### Location
`skills/android-app-icon/SKILL.md`

### Inputs
| Input | Required | Description |
|-------|----------|-------------|
| icon_source | No | User's logo/image file path |
| app_name | No | App name for text-based icon |
| primary_color | No | Primary brand color (hex) |

### Outputs
| Output | Location |
|--------|----------|
| Adaptive icon resources | `app/src/main/res/mipmap-*/` |
| Play Store icon | `fastlane/metadata/android/en-US/images/icon.png` |
| Icon setup instructions | `docs/APP_ICON_SETUP.md` |

### Process

#### Step 1: Analyze Project for Icon Suggestions

```bash
# Extract app name from strings.xml
APP_NAME=$(grep 'name="app_name"' app/src/main/res/values/strings.xml | sed 's/.*>\([^<]*\)<.*/\1/')
echo "App name: $APP_NAME"

# Extract primary color from themes.xml or colors.xml
PRIMARY_COLOR=$(grep 'name="colorPrimary"' app/src/main/res/values/colors.xml | sed 's/.*>\([^<]*\)<.*/\1/')
echo "Primary color: $PRIMARY_COLOR"

# Check if icon resources already exist
if [ -d "app/src/main/res/mipmap-xxxhdpi" ]; then
    echo "Existing icon resources found"
    ls app/src/main/res/mipmap-xxxhdpi/
fi
```

#### Step 2: Display IconKitchen Instructions

Generate `docs/APP_ICON_SETUP.md`:

```markdown
# App Icon Setup Guide

## Step 1: Generate Icon with IconKitchen

Open IconKitchen in your browser:

**[https://icon.kitchen/](https://icon.kitchen/)**

### Recommended Settings

Based on your project analysis:

| Setting | Recommended Value |
|---------|-------------------|
| **Platform** | Android |
| **Icon Type** | Adaptive (for Android 8+) |
| **Foreground** | Your logo or "${APP_NAME}" as text |
| **Background Color** | ${PRIMARY_COLOR} |
| **Shape** | Circle or Squircle (most common) |

### Icon Options

**Option A: Image/Logo**
1. Click "Image" tab
2. Upload your logo (PNG or SVG, ideally 512x512+)
3. Adjust padding so logo has breathing room

**Option B: Clipart**
1. Click "Clipart" tab
2. Search for an icon that represents your app
3. Choose a style (filled, outlined, rounded)

**Option C: Text**
1. Click "Text" tab
2. Enter your app name or initials
3. Choose a font that matches your brand

### Background Options

- **Solid Color**: Use your brand's primary color (${PRIMARY_COLOR})
- **Gradient**: Pick two complementary colors
- **Texture**: Adds visual interest (use sparingly)

## Step 2: Download and Extract

1. Click **"Download"** button in IconKitchen
2. Select **"Android"** format
3. Save the ZIP file
4. Extract to a temporary location

The ZIP contains:
```
android/
├── mipmap-mdpi/
│   └── ic_launcher.webp
├── mipmap-hdpi/
│   └── ic_launcher.webp
├── mipmap-xhdpi/
│   └── ic_launcher.webp
├── mipmap-xxhdpi/
│   └── ic_launcher.webp
├── mipmap-xxxhdpi/
│   └── ic_launcher.webp
└── play_store_512.png    # <-- This is for Play Store
```

## Step 3: Copy to Project

Run these commands from your project root:

```bash
# Copy mipmap resources (replace existing)
cp -r /path/to/extracted/android/mipmap-* app/src/main/res/

# Copy Play Store icon to Fastlane metadata
cp /path/to/extracted/android/play_store_512.png \
   fastlane/metadata/android/en-US/images/icon.png
```

## Step 4: Verify AndroidManifest

Ensure your `AndroidManifest.xml` references the icon:

```xml
<application
    android:icon="@mipmap/ic_launcher"
    android:roundIcon="@mipmap/ic_launcher_round"
    ...>
```

## Step 5: Build and Verify

```bash
# Clean and rebuild
./gradlew clean assembleDebug

# Install and check icon on device/emulator
./gradlew installDebug
```

## Play Store Requirements

| Asset | Size | Format | Notes |
|-------|------|--------|-------|
| App Icon | 512 x 512 px | PNG | No transparency, no rounded corners |

IconKitchen's `play_store_512.png` meets these requirements.

## Troubleshooting

### "Icon looks pixelated"
- Ensure source image is at least 512x512
- Use SVG if possible for best scaling

### "Icon has wrong shape on some devices"
- Android 8+ uses adaptive icons which can be masked to different shapes
- Ensure important content is in the center "safe zone" (66dp circle)

### "Monochrome icon not showing in Android 13"
- IconKitchen generates monochrome versions automatically
- Check that `ic_launcher.xml` has a `<monochrome>` layer
```

#### Step 3: Create Icon Processing Script (Optional Helper)

Create `scripts/process-icon.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Process IconKitchen download and place in correct locations
# Usage: ./scripts/process-icon.sh /path/to/iconkitchen-download.zip

ZIP_PATH="${1:-}"

if [ -z "$ZIP_PATH" ]; then
    echo "Usage: $0 <path-to-iconkitchen-zip>"
    echo ""
    echo "Download your icon from https://icon.kitchen/ and provide the ZIP path."
    exit 1
fi

if [ ! -f "$ZIP_PATH" ]; then
    echo "Error: File not found: $ZIP_PATH"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📦 Extracting icon assets..."
unzip -q "$ZIP_PATH" -d "$TEMP_DIR"

# Find the android directory (might be nested)
ANDROID_DIR=$(find "$TEMP_DIR" -type d -name "android" | head -1)

if [ -z "$ANDROID_DIR" ]; then
    # Try looking for mipmap directories directly
    ANDROID_DIR=$(find "$TEMP_DIR" -type d -name "mipmap-*" -exec dirname {} \; | head -1)
fi

if [ -z "$ANDROID_DIR" ]; then
    echo "Error: Could not find Android icon resources in ZIP"
    exit 1
fi

echo "📱 Copying mipmap resources..."
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    SRC_DIR="$ANDROID_DIR/mipmap-$density"
    DEST_DIR="app/src/main/res/mipmap-$density"
    
    if [ -d "$SRC_DIR" ]; then
        mkdir -p "$DEST_DIR"
        cp -r "$SRC_DIR"/* "$DEST_DIR/"
        echo "  ✓ mipmap-$density"
    fi
done

# Copy Play Store icon
echo "🏪 Copying Play Store icon..."
PLAY_STORE_ICON=$(find "$ANDROID_DIR" -name "play_store_*.png" | head -1)
if [ -n "$PLAY_STORE_ICON" ]; then
    mkdir -p fastlane/metadata/android/en-US/images
    cp "$PLAY_STORE_ICON" fastlane/metadata/android/en-US/images/icon.png
    echo "  ✓ Play Store icon (512x512)"
else
    echo "  ⚠ Play Store icon not found in ZIP"
fi

echo ""
echo "✅ Icon assets installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Rebuild: ./gradlew clean assembleDebug"
echo "  2. Verify icon on device"
echo "  3. Commit changes: git add app/src/main/res/mipmap-* fastlane/metadata/"
```

Make executable:
```bash
chmod +x scripts/process-icon.sh
```

### Verification

```bash
# Check icon resources exist
ls -la app/src/main/res/mipmap-xxxhdpi/

# Check Play Store icon
ls -la fastlane/metadata/android/en-US/images/icon.png

# Verify icon dimensions
file fastlane/metadata/android/en-US/images/icon.png
# Should show: PNG image data, 512 x 512

# Build to verify
./gradlew assembleDebug
```

### Completion Criteria

- [ ] `docs/APP_ICON_SETUP.md` generated with project-specific instructions
- [ ] `scripts/process-icon.sh` created (optional helper)
- [ ] Mipmap resources copied to `app/src/main/res/mipmap-*/`
- [ ] Play Store icon at `fastlane/metadata/android/en-US/images/icon.png`
- [ ] Icon is 512x512 PNG
- [ ] `./gradlew assembleDebug` builds successfully with new icon

---

## Part 4: android-store-listing

### Purpose
Create feature graphic and complete store listing metadata.

### Location
`skills/android-store-listing/SKILL.md`

### Inputs
| Input | Required | Description |
|-------|----------|-------------|
| app_name | Yes | App name |
| tagline | Yes | Short tagline for feature graphic |
| primary_color | No | Primary brand color |
| description | No | Full app description |

### Outputs
| Output | Location |
|--------|----------|
| Feature graphic | `fastlane/metadata/android/en-US/images/featureGraphic.png` |
| Store listing guide | `docs/STORE_LISTING_GUIDE.md` |
| Metadata templates | `fastlane/metadata/android/en-US/*.txt` |

### Play Store Asset Requirements

| Asset | Dimensions | Format | Required |
|-------|------------|--------|----------|
| App Icon | 512 x 512 px | PNG | Yes |
| Feature Graphic | 1024 x 500 px | PNG/JPEG | Yes |
| Phone Screenshots | 320-3840 px (16:9 or 9:16) | PNG/JPEG | 2-8 required |
| 7" Tablet Screenshots | 320-3840 px (16:9 or 9:16) | PNG/JPEG | Up to 8 |
| 10" Tablet Screenshots | 320-3840 px (16:9 or 9:16) | PNG/JPEG | Up to 8 |
| Promo Video | YouTube URL | - | Optional |

### Process

#### Step 1: Generate Store Listing Guide

Create `docs/STORE_LISTING_GUIDE.md`:

```markdown
# Play Store Listing Guide

## Required Assets Checklist

### Graphics (Required)

- [ ] **App Icon** (512 x 512 px)
  - Location: `fastlane/metadata/android/en-US/images/icon.png`
  - Run `/devtools:android-app-icon` to generate

- [ ] **Feature Graphic** (1024 x 500 px)
  - Location: `fastlane/metadata/android/en-US/images/featureGraphic.png`
  - See "Feature Graphic" section below

- [ ] **Phone Screenshots** (2-8 required, min 1080px for promotion eligibility)
  - Location: `fastlane/metadata/android/en-US/images/phoneScreenshots/`
  - Run `/devtools:android-screenshot-automation` to generate

### Graphics (Optional but Recommended)

- [ ] **7" Tablet Screenshots** (up to 8)
  - Location: `fastlane/metadata/android/en-US/images/sevenInchScreenshots/`

- [ ] **10" Tablet Screenshots** (up to 8)
  - Location: `fastlane/metadata/android/en-US/images/tenInchScreenshots/`

- [ ] **Promo Video** (YouTube URL)
  - Location: `fastlane/metadata/android/en-US/video.txt`

---

## Feature Graphic

The feature graphic is displayed at the top of your Play Store listing. It should:
- Communicate your app's value proposition at a glance
- Use your brand colors
- Include your app name and/or logo
- Optionally include a tagline

### Creating a Feature Graphic

**Option A: Canva (Easiest)**
1. Go to [canva.com](https://canva.com)
2. Create custom design: 1024 x 500 px
3. Search templates for "app feature graphic" or "banner"
4. Customize with your app name and colors
5. Download as PNG

**Option B: Figma (More Control)**
1. Open [Figma Community Template](https://www.figma.com/community/file/1090631890869514577)
2. Duplicate to your account
3. Customize the feature graphic frame
4. Export as PNG at 1x

**Option C: AppMockUp (Quick)**
1. Go to [app-mockup.com](https://app-mockup.com)
2. Upload your screenshots
3. Create feature graphic with device frames
4. Download

### Feature Graphic Best Practices

✅ **Do:**
- Use high contrast text
- Keep text minimal (3-5 words)
- Show your app's primary screen
- Use your brand colors
- Leave space for the Play Store overlay

❌ **Don't:**
- Include pricing or "free" text
- Use excessive text
- Make it too busy/cluttered
- Use low-resolution images

---

## Store Listing Metadata

### Title (Max 30 characters)
Location: `fastlane/metadata/android/en-US/title.txt`

Tips:
- Front-load keywords
- Include brand name
- Be descriptive but concise

### Short Description (Max 80 characters)
Location: `fastlane/metadata/android/en-US/short_description.txt`

Tips:
- Highlight main benefit
- Include primary keyword
- Call to action optional

### Full Description (Max 4000 characters)
Location: `fastlane/metadata/android/en-US/full_description.txt`

Structure:
1. Opening hook (what problem does it solve?)
2. Key features (bullet points)
3. Why choose this app?
4. Call to action

### Release Notes
Location: `fastlane/metadata/android/en-US/changelogs/default.txt`

Tips:
- Focus on user-visible changes
- Be specific but concise
- Max 500 characters

---

## Uploading to Play Store

Once all assets are ready:

```bash
# Upload metadata only (no build)
bundle exec fastlane upload_metadata

# Upload screenshots only
bundle exec fastlane upload_screenshots

# Full release (includes everything)
bundle exec fastlane deploy_internal
```

---

## Multi-Language Support

To add additional languages:

1. Create locale directory:
   ```bash
   mkdir -p fastlane/metadata/android/de-DE/images/phoneScreenshots
   ```

2. Copy and translate metadata files:
   ```bash
   cp fastlane/metadata/android/en-US/*.txt fastlane/metadata/android/de-DE/
   # Edit files with German translations
   ```

3. Update Screengrabfile to capture additional locales:
   ```ruby
   locales(["en-US", "de-DE"])
   ```

4. Run screenshot automation for all locales:
   ```bash
   bundle exec fastlane screenshots
   ```

---

## Asset Validation

Before uploading, validate your assets:

```bash
# Check icon dimensions
file fastlane/metadata/android/en-US/images/icon.png
# Expected: PNG image data, 512 x 512

# Check feature graphic dimensions
file fastlane/metadata/android/en-US/images/featureGraphic.png
# Expected: PNG image data, 1024 x 500

# Check screenshot count
ls fastlane/metadata/android/en-US/images/phoneScreenshots/ | wc -l
# Expected: 2-8 files

# Check metadata character limits
wc -c fastlane/metadata/android/en-US/title.txt
# Must be < 30 characters

wc -c fastlane/metadata/android/en-US/short_description.txt
# Must be < 80 characters

wc -c fastlane/metadata/android/en-US/full_description.txt
# Must be < 4000 characters
```
```

#### Step 2: Create Feature Graphic Generation Script (Simple Python)

Create `scripts/generate-feature-graphic.py`:

```python
#!/usr/bin/env python3
"""
Generate a simple feature graphic for Play Store.

Usage: python3 scripts/generate-feature-graphic.py "App Name" "Tagline" "#6200EE"

Requires: pip install Pillow
"""

import sys
import os

def main():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Error: Pillow not installed. Run: pip install Pillow")
        sys.exit(1)
    
    # Parse arguments
    app_name = sys.argv[1] if len(sys.argv) > 1 else "My App"
    tagline = sys.argv[2] if len(sys.argv) > 2 else ""
    bg_color = sys.argv[3] if len(sys.argv) > 3 else "#6200EE"
    
    # Feature graphic dimensions
    width, height = 1024, 500
    
    # Create image with background color
    img = Image.new('RGB', (width, height), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Try to use a nice font, fall back to default
    try:
        # Try system fonts
        font_paths = [
            "/System/Library/Fonts/Helvetica.ttc",  # macOS
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",  # Linux
            "C:\\Windows\\Fonts\\arial.ttf",  # Windows
        ]
        title_font = None
        for path in font_paths:
            if os.path.exists(path):
                title_font = ImageFont.truetype(path, 72)
                tagline_font = ImageFont.truetype(path, 36)
                break
        if title_font is None:
            raise Exception("No font found")
    except:
        title_font = ImageFont.load_default()
        tagline_font = title_font
    
    # Calculate text position (centered)
    text_color = "white"
    
    # Draw app name
    bbox = draw.textbbox((0, 0), app_name, font=title_font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (width - text_width) // 2
    y = (height - text_height) // 2 - 30
    draw.text((x, y), app_name, fill=text_color, font=title_font)
    
    # Draw tagline if provided
    if tagline:
        bbox = draw.textbbox((0, 0), tagline, font=tagline_font)
        text_width = bbox[2] - bbox[0]
        x = (width - text_width) // 2
        y = y + text_height + 20
        draw.text((x, y), tagline, fill=text_color, font=tagline_font)
    
    # Ensure output directory exists
    output_dir = "fastlane/metadata/android/en-US/images"
    os.makedirs(output_dir, exist_ok=True)
    
    # Save
    output_path = os.path.join(output_dir, "featureGraphic.png")
    img.save(output_path, "PNG")
    print(f"✅ Feature graphic saved to: {output_path}")
    print(f"   Dimensions: {width} x {height} px")
    print(f"   Background: {bg_color}")
    print("")
    print("💡 Tip: For a more polished graphic, use Canva or Figma.")
    print("   See docs/STORE_LISTING_GUIDE.md for details.")

if __name__ == "__main__":
    main()
```

Make executable:
```bash
chmod +x scripts/generate-feature-graphic.py
```

### Verification

```bash
# Check all metadata files exist
ls -la fastlane/metadata/android/en-US/

# Validate metadata character limits
wc -c fastlane/metadata/android/en-US/*.txt

# Check images exist
ls -la fastlane/metadata/android/en-US/images/

# Generate simple feature graphic
python3 scripts/generate-feature-graphic.py "My App" "The best app ever" "#6200EE"
```

### Completion Criteria

- [ ] `docs/STORE_LISTING_GUIDE.md` created with full instructions
- [ ] `scripts/generate-feature-graphic.py` created
- [ ] All metadata files in `fastlane/metadata/android/en-US/`:
  - [ ] `title.txt`
  - [ ] `short_description.txt`
  - [ ] `full_description.txt`
  - [ ] `changelogs/default.txt`
- [ ] Feature graphic at `fastlane/metadata/android/en-US/images/featureGraphic.png`

---

## Part 5: Update Existing Skills

### 5.1 Update android-playstore-setup

**File:** `skills/android-playstore-setup/SKILL.md`

**Changes:**
- Remove GPP references
- Add Fastlane setup as Step 1
- Update workflow references to use Fastlane

**Key sections to update:**

```markdown
## What This Does

Sets up everything needed for automated Play Store deployment using **Fastlane**:
1. **Fastlane Setup** - Configure Fastlane with supply and screengrab
2. **App Icon** - Generate and place icon assets
3. **Screenshots** - Automated screenshot capture
4. **Store Listing** - Feature graphic and metadata
5. **Service Account** - Play Store API access
6. **GitHub Actions** - CI/CD workflows

## Process

### Step 1: Setup Fastlane

Run `/devtools:android-fastlane-setup`

### Step 2: Generate App Icon

Run `/devtools:android-app-icon`

### Step 3: Setup Screenshot Automation

Run `/devtools:android-screenshot-automation`

### Step 4: Create Store Listing Assets

Run `/devtools:android-store-listing`

### Step 5: Configure GitHub Actions

Run `/devtools:android-workflow-internal`
```

### 5.2 Update android-workflow-internal

**File:** `skills/android-workflow-internal/SKILL.md`

**Changes:**
- Replace GPP commands with Fastlane
- Update workflow to use `bundle exec fastlane`

**Updated workflow template:**

```yaml
name: Release to Internal Track

on:
  workflow_dispatch:
    inputs:
      version_bump:
        description: 'Version bump type'
        required: true
        type: choice
        options:
          - patch
          - minor
          - major
        default: 'patch'

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout code
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up JDK 17
        uses: actions/setup-java@c5195efecf7bdfc987ee8bae7a71cb8b11521c00  # v4.7.0
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Setup Gradle cache
        uses: actions/cache@1bd1e32a3bdc45362d1e726936510720a7c30a57  # v4.2.0
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
          restore-keys: |
            gradle-${{ runner.os }}-

      - name: Calculate Version
        id: version
        run: |
          chmod +x scripts/gradle-version.sh
          scripts/gradle-version.sh generate ${{ inputs.version_bump }}

      - name: Update version.properties
        run: |
          scripts/gradle-version.sh update ${{ steps.version.outputs.version }}

      - name: Commit Version Bump
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add version.properties
          git commit -m "chore: release v${{ steps.version.outputs.version }}"
          git push origin main

      - name: Decode Keystore
        env:
          ENCODED_KEYSTORE: ${{ secrets.SIGNING_KEY_STORE_BASE64 }}
        run: |
          echo $ENCODED_KEYSTORE | base64 -d > app/release.jks

      - name: Create Service Account File
        env:
          SERVICE_ACCOUNT_JSON: ${{ secrets.SERVICE_ACCOUNT_JSON }}
        run: |
          echo "$SERVICE_ACCOUNT_JSON" > service-account.json

      - name: Deploy with Fastlane
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/app/release.jks
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
          PLAY_STORE_SERVICE_ACCOUNT: service-account.json
        run: |
          bundle exec fastlane deploy_internal

      - name: Create Git Tag
        run: |
          git tag -a ${{ steps.version.outputs.tag }} -m "Release ${{ steps.version.outputs.version }}"
          git push origin ${{ steps.version.outputs.tag }}

      - name: Cleanup
        if: always()
        run: |
          rm -f app/release.jks
          rm -f service-account.json

      - name: Release Summary
        run: |
          echo "## Release Complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Property | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|----------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Version | ${{ steps.version.outputs.version }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Tag | ${{ steps.version.outputs.tag }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Track | Internal |" >> $GITHUB_STEP_SUMMARY
```

### 5.3 Update android-workflow-beta

**File:** `skills/android-workflow-beta/SKILL.md`

**Changes:**
- Replace GPP with Fastlane
- Use `bundle exec fastlane deploy_beta`

### 5.4 Update android-workflow-production

**File:** `skills/android-workflow-production/SKILL.md`

**Changes:**
- Replace GPP with Fastlane
- Use `bundle exec fastlane deploy_production`
- Use `bundle exec fastlane increase_rollout` for rollout management

---

## Part 6: Commands to Create/Update

### New Commands

| Command | File |
|---------|------|
| `/devtools:android-fastlane-setup` | `commands/devtools/android-fastlane-setup.md` |
| `/devtools:android-screenshot-automation` | `commands/devtools/android-screenshot-automation.md` |
| `/devtools:android-app-icon` | `commands/devtools/android-app-icon.md` |
| `/devtools:android-store-listing` | `commands/devtools/android-store-listing.md` |

### Command Templates

#### android-fastlane-setup.md

```markdown
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
```

#### android-screenshot-automation.md

```markdown
---
description: Setup automated screenshot capture for Play Store using Fastlane Screengrab
---

# Android Screenshot Automation

Configures Fastlane Screengrab for automated screenshot capture across locales and devices.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-screenshot-automation/SKILL.md`

## Completion Criteria

- [ ] Screengrab dependency added
- [ ] Debug manifest has required permissions
- [ ] `ScreenshotTest.kt` captures key screens
- [ ] `bundle exec fastlane screenshots` runs successfully
- [ ] Screenshots in `fastlane/metadata/android/en-US/images/phoneScreenshots/`

## Quick Reference

**Inputs:** Screens to capture, locales
**Outputs:** Screenshot test class, captured screenshots
**Verify:** `bundle exec fastlane screenshots`

## Related Commands

- `/devtools:android-fastlane-setup` - Required first
- `/devtools:android-e2e-tests` - Existing test infrastructure
```

#### android-app-icon.md

```markdown
---
description: Generate app icon using IconKitchen and place in correct locations
---

# Android App Icon

Guides you through IconKitchen to generate adaptive app icons, then places assets correctly.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-app-icon/SKILL.md`

## Completion Criteria

- [ ] Icon generated via IconKitchen
- [ ] Mipmap resources in `app/src/main/res/mipmap-*/`
- [ ] Play Store icon at `fastlane/metadata/android/en-US/images/icon.png`
- [ ] Icon is 512x512 PNG
- [ ] App builds successfully with new icon

## Quick Reference

**Inputs:** Logo/image file, app name, primary color
**Outputs:** Adaptive icons, Play Store icon (512x512)
**Verify:** `./gradlew assembleDebug`

## Related Commands

- `/devtools:android-store-listing` - Feature graphic and metadata
```

#### android-store-listing.md

```markdown
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
```

---

## Implementation Checklist

### New Skills
- [ ] Create `skills/android-fastlane-setup/SKILL.md`
- [ ] Create `skills/android-screenshot-automation/SKILL.md`
- [ ] Create `skills/android-app-icon/SKILL.md`
- [ ] Create `skills/android-store-listing/SKILL.md`

### Updated Skills
- [ ] Update `skills/android-playstore-setup/SKILL.md` (orchestrator)
- [ ] Update `skills/android-workflow-internal/SKILL.md` (Fastlane)
- [ ] Update `skills/android-workflow-beta/SKILL.md` (Fastlane)
- [ ] Update `skills/android-workflow-production/SKILL.md` (Fastlane)

### New Commands
- [ ] Create `commands/devtools/android-fastlane-setup.md`
- [ ] Create `commands/devtools/android-screenshot-automation.md`
- [ ] Create `commands/devtools/android-app-icon.md`
- [ ] Create `commands/devtools/android-store-listing.md`

### Templates/Scripts
- [ ] Create `skills/android-fastlane-setup/templates/Gemfile`
- [ ] Create `skills/android-fastlane-setup/templates/Fastfile`
- [ ] Create `skills/android-fastlane-setup/templates/Appfile`
- [ ] Create `skills/android-fastlane-setup/templates/Screengrabfile`
- [ ] Create `skills/android-screenshot-automation/templates/ScreenshotTest.kt`
- [ ] Create `skills/android-screenshot-automation/templates/DemoModeRule.kt`
- [ ] Create `skills/android-app-icon/templates/process-icon.sh`
- [ ] Create `skills/android-store-listing/templates/generate-feature-graphic.py`

### Documentation
- [ ] Update `IMPLEMENTATION_SUMMARY.md`
- [ ] Update skill index/README

---

## Verification

After implementation:

```bash
# Verify new skills exist
ls skills/android-fastlane-setup/
ls skills/android-screenshot-automation/
ls skills/android-app-icon/
ls skills/android-store-listing/

# Verify commands exist
ls commands/devtools/android-fastlane-setup.md
ls commands/devtools/android-screenshot-automation.md
ls commands/devtools/android-app-icon.md
ls commands/devtools/android-store-listing.md

# Verify no GPP references in updated skills
grep -r "gradle-play-publisher\|publishReleaseBundle\|r0adkll" skills/android-workflow-* || echo "✓ No GPP references"

# Verify Fastlane references
grep -r "fastlane\|bundle exec" skills/android-workflow-* && echo "✓ Fastlane references found"
```

---

## Summary

This spec replaces GPP with Fastlane for a complete Play Store deployment solution:

| Capability | Old (GPP) | New (Fastlane) |
|------------|-----------|----------------|
| Screenshot automation | ❌ None | ✅ Screengrab |
| Metadata management | ⚠️ Release notes only | ✅ Full (title, description, screenshots) |
| Deployment | ✅ `publishReleaseBundle` | ✅ `supply` |
| Rollout management | ✅ GPP flags | ✅ Fastlane lanes |
| Multi-locale | ❌ Manual | ✅ Automated |
| CI/CD | ✅ Gradle-native | ✅ Ruby + bundle exec |

**Benefits:**
- One tool for everything (screenshots + metadata + deployment)
- Industry standard (widely used, well-documented)
- Matches your existing Media-Player-Omega setup
- Better metadata management than GPP
