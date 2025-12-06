---
name: android-release-validation
description: Validate Android release builds before publishing to ensure quality and catch ProGuard issues
category: android
version: 1.0.0
---

# Android Release Validation

This skill validates Android release builds to catch issues before they reach production. Critical for ensuring ProGuard/R8 doesn't break functionality and that the release build is production-ready.

## What This Does

1. **Build Release Artifacts**
   - Builds release APK and AAB
   - Verifies build succeeds with ProGuard/R8 enabled
   - Checks build outputs are generated correctly
   - Validates file sizes are reasonable

2. **Run E2E Tests on Release Build**
   - Executes Espresso tests against release APK
   - Catches ProGuard/R8 breaking functionality
   - Verifies obfuscated code still works
   - Tests on release configuration (not debug)

3. **Validate Signing Configuration**
   - Verifies release build is signed correctly
   - Checks keystore configuration
   - Validates signing credentials
   - Ensures signature is valid

4. **Validate ProGuard Mapping**
   - Checks mapping file exists
   - Verifies mapping file is not empty
   - Validates file can be used for deobfuscation
   - Critical for crash reporting

5. **Check Build Metadata**
   - Validates version code/name
   - Checks package name
   - Verifies minimum/target SDK versions
   - Validates permissions

6. **APK/AAB Analysis**
   - Checks file sizes (warns if too large)
   - Validates APK structure
   - Checks for debug symbols (should be stripped)
   - Verifies resources are optimized

## Prerequisites

- Android project with Gradle
- Release build configured (android-release-build-setup)
- E2E tests created (android-e2e-testing-setup)
- Signing keystore configured
- ProGuard/R8 enabled

## Parameters

None required - skill will detect project configuration and validate accordingly.

## Step-by-Step Process

### Step 1: Pre-Validation Checks

Verify prerequisites are met:

```kotlin
// Check that release build is configured
// - signingConfig exists
// - isMinifyEnabled = true
// - proguard-rules.pro exists

// Check that tests exist
// - androidTest directory exists
// - At least one test file present

// Check that keystore is configured
// - For local: gradle.properties has signing config
// - For CI: environment variables are available
```

**Ask the user:**
- "Run full validation (includes E2E tests) or quick validation (build only)?"
- "Validate APK, AAB, or both?"
- "Use local dev keystore or production keystore?" (if both available)

### Step 2: Clean Build

Start with clean slate:

```bash
./gradlew clean

# Remove build outputs
rm -rf app/build/outputs/

# Optional: Clear gradle cache for fresh build
# rm -rf .gradle/
```

**Why:** Ensures we're testing a fresh build, not using cached artifacts.

### Step 3: Build Release APK

Build release APK with ProGuard/R8:

```bash
./gradlew assembleRelease

# Expected output location:
# app/build/outputs/apk/release/app-release.apk
```

**Validations:**
- Build succeeds without errors
- ProGuard/R8 runs successfully
- APK file is generated
- APK size is reasonable (< 100MB warning threshold)

**Capture:**
- Build time
- APK size
- Number of methods (DEX count)
- Any ProGuard warnings

### Step 4: Build Release AAB (Android App Bundle)

Build release AAB for Play Store:

```bash
./gradlew bundleRelease

# Expected output location:
# app/build/outputs/bundle/release/app-release.aab
```

**Validations:**
- Build succeeds without errors
- AAB file is generated
- AAB size is reasonable
- Base module included

**Capture:**
- Build time
- AAB size
- Modules included

### Step 5: Validate Signing

Verify APK/AAB is properly signed:

```bash
# Check APK signature
jarsigner -verify -verbose -certs app/build/outputs/apk/release/app-release.apk

# Check AAB signature (extract first)
unzip -p app/build/outputs/bundle/release/app-release.aab META-INF/MANIFEST.MF
```

**Validations:**
- APK/AAB is signed
- Signature is valid
- Certificate matches expected keystore
- Signature algorithm is secure (SHA256withRSA or better)

**Warnings:**
- Using debug keystore for release (CRITICAL ERROR)
- Weak signature algorithm
- Certificate expires soon (< 6 months)

### Step 6: Validate ProGuard Mapping

Check mapping file exists and is valid:

```bash
# Default location
ls -lh app/build/outputs/mapping/release/mapping.txt

# Verify file is not empty
[ -s app/build/outputs/mapping/release/mapping.txt ] && echo "Mapping file OK" || echo "Mapping file EMPTY"

# Check file size (should be substantial if minification is working)
du -h app/build/outputs/mapping/release/mapping.txt
```

**Validations:**
- Mapping file exists
- File is not empty (size > 1KB)
- File contains obfuscation mappings
- Format is valid

**Why Critical:**
Without mapping file:
- Cannot deobfuscate crash reports
- Cannot debug production issues
- Stack traces will be unreadable

### Step 7: Analyze APK Contents

Use Android tools to analyze APK:

```bash
# Get APK info (package name, version, permissions)
aapt dump badging app/build/outputs/apk/release/app-release.apk

# Get detailed APK contents
aapt list -v app/build/outputs/apk/release/app-release.apk

# Check for debug symbols (should not be present in release)
aapt list -v app/build/outputs/apk/release/app-release.apk | grep -i debug

# Analyze APK with apkanalyzer (if available)
apkanalyzer apk summary app/build/outputs/apk/release/app-release.apk
```

**Extract and validate:**
- Package name matches expected
- Version code/name correct
- Minimum SDK version
- Target SDK version
- Permissions list
- Native libraries (if any)
- DEX file count and size

**Warnings:**
- APK > 100MB (consider optimization)
- Debug symbols present (should be stripped)
- Excessive permissions
- targetSdk < 33 (Play Store requirement)

### Step 8: Run E2E Tests on Release Build

Execute instrumented tests on release APK:

```bash
# Install release APK on device/emulator
adb install -r app/build/outputs/apk/release/app-release.apk

# Run tests against release build
./gradlew connectedReleaseAndroidTest

# Alternative: Run specific critical tests only
./gradlew connectedReleaseAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.app.ExampleInstrumentedTest
```

**Why Critical:**
ProGuard/R8 can break functionality by:
- Removing classes used via reflection
- Breaking serialization
- Stripping required native methods
- Removing classes referenced in XML

**Validations:**
- All tests pass on release build
- No crashes during test execution
- UI interactions work correctly
- Navigation functions properly

**If tests fail:**
1. Check ProGuard rules
2. Add keep rules for affected classes
3. Rebuild and re-test
4. Repeat until all tests pass

### Step 9: Test Installation and Basic Functionality

Manual validation steps:

```bash
# Uninstall any existing version
adb uninstall com.example.app

# Install release APK
adb install app/build/outputs/apk/release/app-release.apk

# Launch app
adb shell am start -n com.example.app/.MainActivity

# Check for crashes in logcat
adb logcat -T 1 | grep -i "crash\|fatal\|error"
```

**Manual checks:**
- App launches successfully
- No immediate crashes
- Main screen displays correctly
- Basic navigation works
- No obvious UI glitches

### Step 10: Validate APK Size and Optimization

Check APK is optimized:

```bash
# Check uncompressed APK size
unzip -l app/build/outputs/apk/release/app-release.apk | tail -1

# Check for large resources
unzip -l app/build/outputs/apk/release/app-release.apk | sort -k4 -n -r | head -20

# Verify resources are optimized
# - Images should be compressed
# - Unused resources should be removed (shrinkResources = true)
```

**Optimization checks:**
- Resource shrinking enabled (isShrinkResources = true)
- No duplicate resources
- Images are compressed
- No debug resources included
- Unused code removed

**Size thresholds:**
- < 20MB: Excellent
- 20-50MB: Good
- 50-100MB: Warning (consider optimization)
- > 100MB: Critical (Play Store has limits)

### Step 11: Validate Release Build (MANDATORY)

**CRITICAL: This step is MANDATORY and must pass before completing the skill.**

Execute actual validation:

```bash
# 1. REQUIRED: Build release APK and AAB
./gradlew clean
./gradlew bundleRelease
./gradlew assembleRelease

# 2. REQUIRED: Verify outputs exist
ls -lh app/build/outputs/bundle/release/app-release.aab
ls -lh app/build/outputs/apk/release/app-release.apk
ls -lh app/build/outputs/mapping/release/mapping.txt

# 3. REQUIRED: Verify signing
jarsigner -verify -verbose -certs app/build/outputs/apk/release/app-release.apk

# 4. REQUIRED: Run E2E tests on release build
./gradlew connectedReleaseAndroidTest

# 5. REQUIRED: Verify ProGuard mapping is not empty
[ -s app/build/outputs/mapping/release/mapping.txt ] && echo "✓ Mapping file OK" || echo "✗ Mapping file empty"
```

**Expected output:**
- AAB exists: ✓
- APK exists: ✓
- Mapping exists and not empty: ✓
- APK signed correctly: ✓ "jar verified"
- E2E tests pass on release: ✓

**If ANY fail:**
1. DO NOT complete skill
2. Investigate error
3. Fix issue
4. Re-run validation
5. Only complete when ALL pass

**Common Failures:**
- "ProGuard error" → Add keep rules
- "Tests fail on release but pass on debug" → ProGuard removed required code
- "Mapping file empty" → Verify isMinifyEnabled = true

### Step 12: Generate Validation Report

Create comprehensive validation report:

```markdown
# Release Build Validation Report

**Build Date:** {DATE}
**Version:** {VERSION_NAME} ({VERSION_CODE})
**Package:** {PACKAGE_NAME}

## Build Status

### APK Build
- Status: ✓ Success / ✗ Failed
- Size: {APK_SIZE} MB
- Location: app/build/outputs/apk/release/app-release.apk
- Build time: {BUILD_TIME} seconds

### AAB Build
- Status: ✓ Success / ✗ Failed
- Size: {AAB_SIZE} MB
- Location: app/build/outputs/bundle/release/app-release.aab
- Build time: {BUILD_TIME} seconds

## Configuration

### SDK Versions
- Minimum SDK: {MIN_SDK}
- Target SDK: {TARGET_SDK}
- Compile SDK: {COMPILE_SDK}

### ProGuard/R8
- Minification: ✓ Enabled
- Resource Shrinking: ✓ Enabled
- Mapping file: ✓ Present ({MAPPING_SIZE} KB)

### Signing
- Signed: ✓ Yes
- Algorithm: {ALGORITHM}
- Certificate: {CERTIFICATE_INFO}

## Test Results

### E2E Tests on Release
- Total tests: {TOTAL}
- Passed: {PASSED}
- Failed: {FAILED}
- Skipped: {SKIPPED}

{TEST_DETAILS}

## APK Analysis

### Size Breakdown
- DEX files: {DEX_SIZE} MB ({DEX_PERCENT}%)
- Resources: {RES_SIZE} MB ({RES_PERCENT}%)
- Native libs: {LIB_SIZE} MB ({LIB_PERCENT}%)
- Assets: {ASSET_SIZE} MB ({ASSET_PERCENT}%)
- Other: {OTHER_SIZE} MB ({OTHER_PERCENT}%)

### Permissions
{PERMISSIONS_LIST}

### Large Files (Top 10)
{LARGE_FILES}

## Issues Found

### Critical Issues
{CRITICAL_ISSUES}

### Warnings
{WARNINGS}

## Recommendations

{RECOMMENDATIONS}

## Validation Summary

Overall Status: ✓ PASSED / ✗ FAILED

{SUMMARY}

---
Generated: {TIMESTAMP}
```

### Step 13: Summary and Next Steps

Provide clear summary:

```
✅ Android Release Build Validation Complete!

📦 Build Artifacts:
  APK: app/build/outputs/apk/release/app-release.apk ({APK_SIZE} MB)
  AAB: app/build/outputs/bundle/release/app-release.aab ({AAB_SIZE} MB)
  Mapping: app/build/outputs/mapping/release/mapping.txt

✓ Build Status:
  ✓ APK build succeeded
  ✓ AAB build succeeded
  ✓ ProGuard/R8 completed successfully
  ✓ Signed with release keystore

✓ Tests:
  ✓ {PASSED}/{TOTAL} E2E tests passed on release build
  ✓ No crashes during testing
  ✓ All critical paths validated

✓ Configuration:
  ✓ ProGuard enabled and working
  ✓ Mapping file generated
  ✓ Resource shrinking active
  ✓ Target SDK 34 (meets Play Store requirements)

✓ Quality Checks:
  ✓ APK size reasonable ({APK_SIZE} MB)
  ✓ No debug symbols in release
  ✓ Signature valid
  ✓ Permissions appropriate

⚠️  Warnings:
  {WARNINGS_IF_ANY}

📋 Next Steps:

  If validation passed:
    1. Save ProGuard mapping file securely
    2. Ready for Play Store upload
    3. Use android-playstore-publishing skill for deployment
  
  If validation failed:
    1. Review issues listed above
    2. Fix ProGuard rules if tests failed
    3. Address any critical warnings
    4. Re-run validation

  ProGuard Mapping:
    - Save to version control (encrypted/secure location)
    - Upload to Play Console with release
    - Store for crash deobfuscation

🔒 Security Reminders:
  - Never commit release APK/AAB to git
  - Store mapping files securely
  - Protect signing keystore
  - Review permissions before release
```

## Error Handling

### Build Fails

**ProGuard/R8 errors:**
```
Error: program class missing: com.example.SomeClass
```

**Solution:**
Add keep rule to proguard-rules.pro:
```proguard
-keep class com.example.SomeClass { *; }
```

**Build timeout:**
- Increase Gradle heap size in gradle.properties
- Check for infinite loops in ProGuard rules
- Review dependency conflicts

### Tests Fail on Release

**Common causes:**
1. ProGuard removed required classes
2. Reflection not working (class names obfuscated)
3. Serialization broken
4. Native methods stripped

**Solution:**
1. Run tests with verbose logging
2. Check stack trace for missing classes
3. Add keep rules for affected classes
4. Rebuild and re-test

### Signing Validation Fails

**Using wrong keystore:**
- Check SIGNING_KEY_STORE_PATH
- Verify passwords are correct
- Ensure using release keystore, not debug

**Signature algorithm weak:**
- Regenerate keystore with SHA256withRSA
- Update signing configuration

### Mapping File Missing

**Causes:**
- ProGuard/R8 disabled
- isMinifyEnabled = false
- Build failed before mapping generated

**Solution:**
- Verify isMinifyEnabled = true in release buildType
- Check build logs for ProGuard errors
- Ensure proguard-rules.pro exists

### APK Too Large

**Size optimization:**
1. Enable resource shrinking: `isShrinkResources = true`
2. Use APK splits for ABIs/densities
3. Convert images to WebP
4. Remove unused resources
5. Use Android App Bundle (AAB) instead of APK

## Security Best Practices

1. **Keystore Protection**
   - Use local dev keystore for validation
   - Never use production keystore locally
   - Store production keystore only in CI/CD

2. **Mapping File Security**
   - Store mapping files securely
   - Don't commit to public repos
   - Keep for each release version
   - Upload to Play Console

3. **APK/AAB Security**
   - Don't commit built artifacts
   - Scan for hardcoded secrets
   - Review permissions before release
   - Enable obfuscation

4. **Validation in CI/CD**
   - Run validation on every release build
   - Block deployment if validation fails
   - Store validation reports
   - Track metrics over time

## Integration with Other Skills

This skill integrates with:
- `android-release-build-setup` - Provides release build configuration
- `android-e2e-testing-setup` - Provides tests to run
- `android-playstore-publishing` - Uses validated build for deployment
- `android-playstore-pipeline` - Part of complete release workflow

## Troubleshooting

### "aapt not found"
Install Android SDK build-tools:
```bash
# Via Android Studio SDK Manager
# Or via command line
sdkmanager "build-tools;34.0.0"
```

### "jarsigner not found"
Install JDK:
```bash
# macOS
brew install openjdk@17

# Ubuntu/Debian
sudo apt install openjdk-17-jdk
```

### "Tests pass on debug but fail on release"
This is the exact issue this validation catches!
1. Check test logs for specific failures
2. Add ProGuard keep rules for affected classes
3. Common issues:
   - Reflection on obfuscated classes
   - Serialization of obfuscated classes
   - Native method bindings

### "APK installs but crashes immediately"
1. Check logcat for crash details
2. Use mapping file to deobfuscate stack trace
3. Common causes:
   - Missing keep rule for Application class
   - Native library not loaded
   - Resource not found

## Files Created/Modified

**Created:**
- `validation-report.md` - Detailed validation report
- `validation-summary.json` - Machine-readable summary

**Modified:**
- None (this is a read-only validation skill)

**Temporary:**
- `app/build/` - Build outputs (can be cleaned)

**Preserved:**
- `app/build/outputs/mapping/release/mapping.txt` - MUST keep for crash reports

## Completion Criteria (ALL MUST PASS)

Do NOT mark this skill as complete unless ALL of the following are verified:

✅ **Validation script created**
  - [ ] validate-release.sh exists and is executable
  - [ ] Script includes all validation checks

✅ **Validation workflow created**
  - [ ] .github/workflows/release-validation.yml exists
  - [ ] Workflow runs on release branches

✅ **MANDATORY: Validation execution**
  - [ ] `./gradlew bundleRelease` succeeds
  - [ ] `./gradlew assembleRelease` succeeds
  - [ ] AAB file exists: app/build/outputs/bundle/release/app-release.aab
  - [ ] APK file exists: app/build/outputs/apk/release/app-release.apk
  - [ ] Mapping file exists and not empty: app/build/outputs/mapping/release/mapping.txt
  - [ ] `jarsigner -verify` confirms valid signature
  - [ ] `./gradlew connectedReleaseAndroidTest` succeeds (E2E tests pass on release)

✅ **Validation report generated**
  - [ ] Report template exists
  - [ ] Report includes all critical checks

**If ANY checkbox is unchecked, the skill is NOT complete.**

## Expected Outcomes

After running this skill:

✅ **Release build validated** - APK and AAB built successfully
✅ **ProGuard working** - Mapping file generated, tests pass
✅ **Signing verified** - Release is properly signed
✅ **Tests passing** - E2E tests work on release build
✅ **Quality assured** - Size, permissions, configuration validated
✅ **Ready for deployment** - Safe to upload to Play Store

## Next Skills (Dependencies)

This skill DEPENDS on:
- `android-release-build-setup` - Must complete first (requires working release build)
- `android-e2e-testing-setup` - Must complete first (uses E2E tests for validation)

This skill is a PREREQUISITE for:
- `android-playstore-publishing` - Only deploy validated builds
- `android-playstore-pipeline` - Part of complete workflow

Do NOT run this skill until both dependencies' completion criteria are met.
Do NOT run publishing skills until this skill's completion criteria are met.

## References

- [ProGuard Manual](https://www.guardsquare.com/manual/home)
- [R8 Documentation](https://developer.android.com/build/shrink-code)
- [APK Analyzer](https://developer.android.com/studio/debug/apk-analyzer)
- [App Signing](https://developer.android.com/studio/publish/app-signing)
- [Publishing Guide](https://developer.android.com/studio/publish)
