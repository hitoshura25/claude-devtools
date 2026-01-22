# Skill File Update Notes for android-app-icon

## Issues Found and Fixed

### Issue 1: IconKitchen Output Structure Changed
**Problem:** IconKitchen now outputs mipmap resources in `android/res/mipmap-*` instead of `android/mipmap-*`

**Impact:** The original script couldn't find any mipmap files in the downloaded zip.

**Fix:** Updated script to detect both formats:
- Newer format: `android/res/mipmap-*`
- Older format: `android/mipmap-*`

### Issue 2: Duplicate Resource Conflicts
**Problem:** Old `.webp` icon files conflicted with new `.png` files from IconKitchen, causing build failures.

**Impact:** Build failed with "Duplicate resources" error for `ic_launcher`.

**Fix:** Script now removes old icon files before copying new ones.

### Issue 3: Missing mipmap-anydpi-v26
**Problem:** The adaptive icon XML configuration wasn't being copied.

**Impact:** Adaptive icons (Android 8+) wouldn't work correctly.

**Fix:** Added explicit handling for `mipmap-anydpi-v26` directory.

### Issue 4: Missing/Incorrect ic_launcher_round.xml
**Problem:**
- IconKitchen only provides `ic_launcher.xml`, not `ic_launcher_round.xml`
- Old `ic_launcher_round.xml` files use `@drawable/` instead of `@mipmap/` references

**Impact:** Runtime crashes or missing round icons on devices that use them.

**Fix:**
- Script creates `ic_launcher_round.xml` from `ic_launcher.xml` if missing
- Automatically fixes old files that reference `@drawable/` to use `@mipmap/`

## Skill File Updates Needed

Update the file: `~/claude-devtools/skills/android-app-icon/SKILL.md`

### Section to Update: "Step 4: Download and Process Icon Assets"

**Current text (lines 83-92):**
```
The ZIP contains:
```
android/
├── mipmap-mdpi/
├── mipmap-hdpi/
├── mipmap-xhdpi/
├── mipmap-xxhdpi/
├── mipmap-xxxhdpi/
└── play_store_512.png
```
```

**Updated text:**
```
The ZIP contains (newer IconKitchen format):
```
android/
├── res/
│   ├── mipmap-anydpi-v26/
│   │   └── ic_launcher.xml
│   ├── mipmap-mdpi/
│   ├── mipmap-hdpi/
│   ├── mipmap-xhdpi/
│   ├── mipmap-xxhdpi/
│   └── mipmap-xxxhdpi/
└── play_store_512.png
```

Note: Older IconKitchen versions may have mipmap-* directly under android/
```

### Section to Update: "Icon Processing Script" (lines 134-174)

**Add this section BEFORE the script:**
```markdown
### Important Script Features

The script automatically:
1. Detects both newer (`android/res/`) and older (`android/`) IconKitchen formats
2. Removes old icon files to prevent duplicate resource conflicts
3. Copies adaptive icon XML configuration (`mipmap-anydpi-v26`)
4. Creates/fixes `ic_launcher_round.xml` (IconKitchen only provides `ic_launcher.xml`)
5. Fixes old XML files that reference `@drawable/` to use `@mipmap/`
6. Installs Play Store icon (512x512)
7. Verifies all assets after installation
```

**Update the script section starting at line 150:**

Add after line 149 (after `# Find android directory` section):
```bash
# Check if resources are in res/ subdirectory (newer IconKitchen format)
# or directly in android/ directory (older format)
if [ -d "$ANDROID_DIR/res" ]; then
    RESOURCE_DIR="$ANDROID_DIR/res"
    echo "📁 Using newer IconKitchen format (android/res/...)"
else
    RESOURCE_DIR="$ANDROID_DIR"
    echo "📁 Using older IconKitchen format (android/...)"
fi
echo ""

# Also check for mipmap-anydpi-v26 (adaptive icon XML)
if [ -d "$RESOURCE_DIR/mipmap-anydpi-v26" ]; then
    echo "📱 Installing adaptive icon configuration..."
    DEST_DIR="app/src/main/res/mipmap-anydpi-v26"
    mkdir -p "$DEST_DIR"
    cp -r "$RESOURCE_DIR/mipmap-anydpi-v26"/* "$DEST_DIR/"

    # IconKitchen only provides ic_launcher.xml, create ic_launcher_round.xml if missing
    if [ -f "$DEST_DIR/ic_launcher.xml" ] && [ ! -f "$DEST_DIR/ic_launcher_round.xml" ]; then
        cp "$DEST_DIR/ic_launcher.xml" "$DEST_DIR/ic_launcher_round.xml"
        echo "  ✓ Created ic_launcher_round.xml from ic_launcher.xml"
    fi

    # Fix old ic_launcher_round.xml that uses @drawable instead of @mipmap
    if [ -f "$DEST_DIR/ic_launcher_round.xml" ]; then
        if grep -q "@drawable" "$DEST_DIR/ic_launcher_round.xml"; then
            sed -i.bak 's/@drawable/@mipmap/g' "$DEST_DIR/ic_launcher_round.xml"
            rm -f "$DEST_DIR/ic_launcher_round.xml.bak"
            echo "  ✓ Fixed ic_launcher_round.xml references (@drawable → @mipmap)"
        fi
    fi

    FILE_COUNT=$(ls -1 "$DEST_DIR" | wc -l | tr -d ' ')
    echo "  ✓ mipmap-anydpi-v26 ($FILE_COUNT files)"
    echo ""
fi

# Remove old icon files to prevent conflicts
echo "🧹 Cleaning old icon files..."
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    DEST_DIR="app/src/main/res/mipmap-$density"
    if [ -d "$DEST_DIR" ]; then
        # Remove old launcher icons (webp and png variants)
        rm -f "$DEST_DIR"/ic_launcher.webp "$DEST_DIR"/ic_launcher_round.webp
        rm -f "$DEST_DIR"/ic_launcher.png "$DEST_DIR"/ic_launcher_round.png
        rm -f "$DEST_DIR"/ic_launcher_foreground.* "$DEST_DIR"/ic_launcher_background.* "$DEST_DIR"/ic_launcher_monochrome.*
    fi
done
echo "  ✓ Old icons removed"
echo ""
```

**Update the for loop (around line 154):**
```bash
# Copy mipmap resources
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    SRC_DIR="$RESOURCE_DIR/mipmap-$density"  # Changed from $ANDROID_DIR/mipmap-$density
    DEST_DIR="app/src/main/res/mipmap-$density"
    # ... rest of loop
done
```

### Section to Update: "Troubleshooting"

**Add new troubleshooting entry after line 213:**
```markdown
### "Duplicate resources" build error
**Cause:** Old icon files (.webp) conflict with new icons (.png)
**Fix:** The updated script automatically removes old icons. If you manually copied files, run:
```bash
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    rm -f app/src/main/res/mipmap-$density/ic_launcher.webp
    rm -f app/src/main/res/mipmap-$density/ic_launcher_round.webp
done
./gradlew clean assembleDebug
```
```

## Testing

The fixed script has been tested with:
- ✅ IconKitchen-Output.zip (newer format with `android/res/`)
- ✅ Duplicate resource conflict resolution
- ✅ Adaptive icon XML installation
- ✅ Build verification (`./gradlew clean assembleDebug`)
- ✅ APK generation

## Files Modified

1. `/Users/vinayakmenon/health-sync-app/scripts/process-icon.sh` - Fixed and tested
2. `/Users/vinayakmenon/health-sync-app/docs/APP_ICON_SETUP.md` - Already uses correct documentation

## Summary for Skill File Maintainer

The main changes needed in `android-app-icon/SKILL.md` are:

1. **Line 83-92:** Update ZIP structure documentation to show `android/res/` path
2. **Line 134:** Add "Important Script Features" section before the script
3. **Line 150-174:** Update script code to:
   - Detect and handle both old and new IconKitchen formats
   - Copy mipmap-anydpi-v26 directory
   - Remove old icon files before copying new ones
   - Use `$RESOURCE_DIR` variable instead of `$ANDROID_DIR` directly
4. **Line 213+:** Add troubleshooting entry for duplicate resources

These changes ensure the skill works with current IconKitchen output format (as of December 2025).

---

# Skill File Update Notes for android-screenshot-automation

## Issues Found

### Issue 1: No Ruby Version Check or Requirements
**Problem:** The skill assumes Fastlane works without checking Ruby version compatibility.

**Impact:**
- Setup completes successfully
- All files created correctly
- But running `bundle exec fastlane screenshots` fails with cryptic errors
- Ruby 3.4 is incompatible with Fastlane 2.229.0 due to:
  - Removed standard library gems (`kconv`, `ostruct`)
  - Changed internal APIs
  - Incompatible gem versions (json 1.8.6)

**What Happened:**
1. User had Ruby 3.4.7 (latest Homebrew version)
2. Skill created all files successfully
3. `./gradlew assembleDebug assembleAndroidTest` succeeded
4. `bundle exec fastlane --version` failed with:
   ```
   uninitialized constant FastlaneCore::UpdateChecker (NameError)
   cannot load such file -- kconv (LoadError)
   ```

**Fix Applied:**
- Added `.ruby-version` file specifying `3.3.7`
- Updated `Gemfile` with Ruby version requirement `ruby "~> 3.3.0"`
- Provided instructions for installing Ruby 3.3.x via rbenv/rvm

### Issue 2: Incorrect Test APK Path with testBuildType = "release"
**Problem:** The skill assumes test APKs are built as `app-debug-androidTest.apk`, but when `testBuildType = "release"` is configured (common for testing ProGuard/R8), the test APK is actually `app-release-androidTest.apk`.

**Impact:**
- Fastlane fails with "APK not found" error
- Error message: Cannot find app-debug-androidTest.apk
- Occurs even though build succeeds

**What Happened:**
1. Project has `testBuildType = "release"` in build.gradle.kts:35
2. This is intentional - needed to test release builds with ProGuard/R8
3. Gradle builds: `app-debug.apk` + `app-release-androidTest.apk`
4. Screengrabfile expects: `app-debug.apk` + `app-debug-androidTest.apk` ❌
5. Fastlane fails to find the test APK

**Fix Applied (Better Solution):**
- Made `testBuildType` configurable in build.gradle.kts:36
- Fastfile overrides to `testBuildType=debug` for screenshots (fast iteration)
- Updated Screengrabfile to use debug APKs (matching signatures)
- Default remains `testBuildType=release` for ProGuard/R8 validation

**Code Changes:**
```kotlin
// build.gradle.kts
testBuildType = project.findProperty("testBuildType")?.toString() ?: "release"
```

```ruby
# Fastfile
gradle(
  task: "assembleDebugAndroidTest",
  properties: { "testBuildType" => "debug" }
)
```

**Root Cause:**
The skill doesn't check for or handle `testBuildType` configuration, and doesn't understand that:
- Debug APK + Release test APK = signature mismatch
- Should use matching build types for app and test APKs

## Skill File Updates Needed

Update the file: `~/claude-devtools/skills/android-screenshot-automation/SKILL.md`

### Section to Add: Prerequisites (Line 23-27)

**Current text:**
```markdown
## Prerequisites

- `/devtools:android-fastlane-setup` completed
- `/devtools:android-e2e-tests` completed (UI Automator tests exist)
- Emulator or device available for testing
```

**Updated text:**
```markdown
## Prerequisites

- `/devtools:android-fastlane-setup` completed
- `/devtools:android-e2e-tests` completed (UI Automator tests exist)
- Emulator or device available for testing
- **Ruby 3.3.x** (Ruby 3.4+ is not yet compatible with Fastlane)
  - Check version: `ruby --version`
  - If Ruby 3.4+, see "Ruby Version Setup" section below
```

### New Section to Add: Detecting testBuildType Configuration

**Add after Process section, before Step 1:**

```markdown
### Checking testBuildType Configuration

Some projects configure `testBuildType = "release"` to test ProGuard/R8 optimizations. This affects which test APK is built.

**Check your build.gradle.kts:**
```bash
grep -n "testBuildType" app/build.gradle.kts
```

**If found:**
- Test APK will be `app-release-androidTest.apk` (not `app-debug-androidTest.apk`)
- Need to update Screengrabfile and Fastfile accordingly
- See "Handling testBuildType = release" section below

**If not found:**
- Default behavior: test APK is `app-debug-androidTest.apk`
- No changes needed
```

### New Section to Add: Handling testBuildType = "release"

**Add to Troubleshooting section:**

```markdown
### Fastlane can't find test APK (testBuildType = "release")
**Cause:** Project uses `testBuildType = "release"` which builds test APK against release variant
**Symptom:**
```
Error: Cannot find app-debug-androidTest.apk
```

**Fix:**
1. Update `fastlane/Screengrabfile`:
   ```ruby
   # APK paths
   app_apk_path("app/build/outputs/apk/debug/app-debug.apk")
   tests_apk_path("app/build/outputs/apk/androidTest/release/app-release-androidTest.apk")
   ```

2. Update `fastlane/Fastfile` build_for_screenshots lane:
   ```ruby
   lane :build_for_screenshots do
     gradle(task: "clean")
     gradle(task: "assembleDebug")
     gradle(task: "assembleReleaseAndroidTest")  # Changed from assembleAndroidTest
   end
   ```

**Why this happens:**
When `testBuildType = "release"` is set, instrumentation tests are built against the release variant to validate ProGuard/R8 optimizations. This is a common and recommended practice for catching minification issues before release.
```

### New Section to Add: After Prerequisites (Line 27)

```markdown
### Ruby Version Setup

**IMPORTANT:** Fastlane requires Ruby 3.3.x. Ruby 3.4+ is not yet supported.

**Check your Ruby version:**
```bash
ruby --version
# Should show 3.3.x
```

**If you have Ruby 3.4+, install Ruby 3.3:**

**Option 1: Using rbenv (Recommended)**
```bash
# Install rbenv if needed
brew install rbenv ruby-build

# Install Ruby 3.3.7
rbenv install 3.3.7

# Set as local version for this project
rbenv local 3.3.7

# Verify
ruby --version  # Should show 3.3.7
```

**Option 2: Using RVM**
```bash
# Install RVM if needed
\curl -sSL https://get.rvm.io | bash -s stable

# Install Ruby 3.3.7
rvm install 3.3.7
rvm use 3.3.7

# Verify
ruby --version
```

**After switching Ruby versions:**
```bash
bundle install  # Reinstall gems with correct Ruby version
```
```

### Section to Add: Process - Step 1 (Before adding dependencies)

**Add verification step before Step 1:**

```markdown
### Step 0: Verify Ruby Version

**CRITICAL:** Check Ruby version before proceeding.

```bash
ruby --version
```

**Requirements:**
- ✅ Ruby 3.3.x - Fully compatible
- ⚠️ Ruby 3.2.x - May work but 3.3 recommended
- ❌ Ruby 3.4+ - **NOT COMPATIBLE** with Fastlane 2.229.0

If you have Ruby 3.4+, follow "Ruby Version Setup" in Prerequisites section above.

**Why Ruby 3.4 doesn't work:**
- `kconv` removed from standard library (needed by CFPropertyList)
- `ostruct` removed from standard library (needed by various gems)
- Changed internal APIs break FastlaneCore::UpdateChecker
- Gem incompatibilities (json 1.8.6 doesn't work)

The Ruby 3.4 ecosystem is catching up, but as of December 2025, Fastlane is not yet compatible.
```

### Section to Update: Troubleshooting (Lines 317-339)

**Add new entry at the beginning:**

```markdown
### "uninitialized constant FastlaneCore::UpdateChecker" or "cannot load such file -- kconv"
**Cause:** Ruby 3.4+ is not compatible with current Fastlane version
**Fix:**
1. Check Ruby version: `ruby --version`
2. If 3.4+, install Ruby 3.3.x:
   ```bash
   # Using rbenv
   rbenv install 3.3.7
   rbenv local 3.3.7

   # Or using rvm
   rvm install 3.3.7
   rvm use 3.3.7
   ```
3. Reinstall gems: `bundle install`
4. Verify: `bundle exec fastlane --version`

**Why this happens:**
Ruby 3.4 removed several standard library gems that Fastlane depends on. The Fastlane team is working on compatibility, but it's not ready as of December 2025.

**Alternative (not recommended):**
You can try updating to a newer Fastlane version when available, but this may introduce other breaking changes.
```

### Files to Create Automatically

The skill should create these files to prevent Ruby version issues:

**1. `.ruby-version`**
```
3.3.7
```

**2. Update Gemfile to include Ruby version**
```ruby
source "https://rubygems.org"

# Ruby 3.4+ is not compatible with Fastlane yet
ruby "~> 3.3.0"

gem "fastlane", "~> 2.220"
```

### Process Changes

**Step 1 should become:**

```markdown
### Step 1: Verify Ruby and Add Screengrab Dependency

**First, verify Ruby version:**
```bash
ruby --version
# Must be 3.3.x (NOT 3.4+)
```

If Ruby 3.4+, stop and follow "Ruby Version Setup" section first.

**Then add dependency to `app/build.gradle.kts`:**
```kotlin
dependencies {
    // Existing test dependencies...

    // Screengrab for automated screenshots
    androidTestImplementation("tools.fastlane:screengrab:2.1.1")
}
```

Sync Gradle after adding.
```

## Implementation Recommendations

### 1. Make testBuildType Configurable (Recommended Approach)

**Best Practice:** Instead of matching the existing testBuildType, make it configurable for different use cases.

**Update build.gradle.kts automatically:**
```kotlin
// Original:
testBuildType = "release"

// Updated (configurable):
testBuildType = project.findProperty("testBuildType")?.toString() ?: "release"
```

**Benefits:**
- Default behavior remains unchanged (release validation)
- Can override for specific tasks (screenshots use debug)
- No signature mismatch issues
- Faster screenshot iteration

**Fastfile configuration:**
```ruby
lane :build_for_screenshots do
  gradle(task: "clean")
  gradle(task: "assembleDebug")
  gradle(
    task: "assembleDebugAndroidTest",
    properties: { "testBuildType" => "debug" }  # Override
  )
end
```

**Screengrabfile configuration:**
```ruby
# Use debug APKs for screenshots (fast iteration)
app_apk_path("app/build/outputs/apk/debug/app-debug.apk")
tests_apk_path("app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk")
```

### Alternative: Detect and Match testBuildType

If making it configurable isn't desired, detect and match the existing configuration:

```bash
# Check for testBuildType in build.gradle.kts
TEST_BUILD_TYPE=$(grep -oP 'testBuildType\s*=\s*"\K[^"]+' app/build.gradle.kts 2>/dev/null || echo "debug")

if [[ "$TEST_BUILD_TYPE" == "release" ]]; then
    echo "📋 Detected testBuildType = \"release\""
    echo "   Will use release APKs for screenshots"
    APP_APK_PATH="app/build/outputs/apk/release/app-release.apk"
    TEST_APK_PATH="app/build/outputs/apk/androidTest/release/app-release-androidTest.apk"
    GRADLE_APP_TASK="assembleRelease"
    GRADLE_TEST_TASK="assembleReleaseAndroidTest"
else
    echo "📋 Using default testBuildType = \"debug\""
    echo "   Will use debug APKs for screenshots"
    APP_APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
    TEST_APK_PATH="app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
    GRADLE_APP_TASK="assembleDebug"
    GRADLE_TEST_TASK="assembleAndroidTest"
fi
```

**Note:** This approach is slower if testBuildType="release" due to ProGuard/R8 optimization.

### 2. Add Proactive Ruby Version Check

The skill should check Ruby version early and warn/fail if incompatible:

```bash
# At the start of skill execution
RUBY_VERSION=$(ruby -v | awk '{print $2}' | cut -d. -f1,2)
if [[ "$RUBY_VERSION" == "3.4" ]] || [[ "$RUBY_VERSION" > "3.4" ]]; then
    echo "❌ Error: Ruby $RUBY_VERSION detected"
    echo "   Fastlane requires Ruby 3.3.x"
    echo "   See documentation for how to install Ruby 3.3"
    exit 1
fi
```

### 2. Create Ruby Configuration Files Automatically

Instead of just documenting the issue, create:
- `.ruby-version` with `3.3.7`
- Update `Gemfile` with Ruby version constraint

### 3. Better Error Messages

If Fastlane fails, detect Ruby version and provide helpful error:

```bash
if ! bundle exec fastlane --version 2>&1; then
    RUBY_VERSION=$(ruby -v)
    echo ""
    echo "❌ Fastlane failed to run"
    echo "📌 Your Ruby version: $RUBY_VERSION"
    echo ""
    echo "If you're using Ruby 3.4+, this is a known issue."
    echo "Install Ruby 3.3.x using rbenv or rvm."
    echo "See docs/SCREENSHOT_AUTOMATION_SETUP.md for instructions."
fi
```

### 4. Update Verification Section

Change verification from:
```bash
bundle exec fastlane screenshots
```

To:
```bash
# Verify Ruby version first
ruby --version  # Must be 3.3.x

# Then run screenshots
bundle exec fastlane screenshots
```

## Summary for Skill File Maintainer

**Critical Issue:** The skill works perfectly EXCEPT for Ruby 3.4 compatibility.

**Required Changes:**
1. Add Ruby version requirements to Prerequisites
2. Add Ruby version verification as Step 0
3. Create `.ruby-version` and update `Gemfile` automatically
4. Add comprehensive troubleshooting for Ruby 3.4 issues
5. Add proactive version checking in any automation scripts
6. **Add testBuildType detection** and configure APK paths accordingly
7. Document testBuildType handling in troubleshooting

**Why This Matters:**
- Ruby 3.4 is the latest Homebrew version (many users will have it)
- Setup appears to succeed but fails at runtime
- Error messages are cryptic (FastlaneCore::UpdateChecker, kconv)
- Users waste time debugging when solution is simple (downgrade Ruby)
- `testBuildType = "release"` is a **recommended practice** for validating ProGuard/R8
- Many production apps use this configuration
- Skill should detect and handle this automatically

**Testing Required:**
- Test with Ruby 3.3.7 ✅ (works perfectly)
- Test with Ruby 3.4.7 ❌ (fails with this skill)
- Test with Ruby 3.2.x ⚠️ (likely works but not verified)

---

**Issue discovered on:** 2025-12-17
**Ruby version affected:** 3.4.7 (and likely all 3.4.x)
**Fastlane version:** 2.229.0
**Status:** Workaround documented, skill updates recommended
