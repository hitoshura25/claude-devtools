---
description: Validate Android release builds to ensure quality and catch ProGuard issues before deployment
---

# Android Release Validation

Validate Android release builds before publishing to catch issues early and ensure production readiness. Critical for detecting ProGuard/R8 problems that break functionality.

## What This Command Does

Comprehensive release build validation:
- ✅ Builds release APK and AAB with ProGuard/R8
- ✅ Runs E2E tests on release build (catches ProGuard issues!)
- ✅ Validates signing configuration
- ✅ Checks ProGuard mapping file generation
- ✅ Analyzes APK size and contents
- ✅ Verifies target SDK and permissions
- ✅ Generates detailed validation report

## Usage

```bash
/devtools:android-release-validate
```

## Interactive Setup

The command will:
1. Ask if you want full validation (with tests) or quick validation (build only)
2. Ask whether to validate APK, AAB, or both
3. Ask which keystore to use (local dev or production)
4. Clean previous build outputs
5. Build release APK and/or AAB
6. Validate signing and ProGuard mapping
7. Run E2E tests on release build (if full validation)
8. Analyze APK contents and size
9. Generate comprehensive validation report

## What Gets Validated

### Build Validation
- ✅ APK builds successfully with ProGuard/R8
- ✅ AAB builds successfully
- ✅ No build errors or warnings
- ✅ Build completes in reasonable time

### ProGuard/R8 Validation
- ✅ Code minification enabled
- ✅ Resource shrinking enabled
- ✅ Mapping file generated
- ✅ Mapping file not empty (> 1KB)
- ✅ Obfuscation working correctly

### Signing Validation
- ✅ APK/AAB is signed
- ✅ Signature is valid
- ✅ Using correct keystore (not debug)
- ✅ Signature algorithm is secure
- ✅ Certificate not expired

### Test Validation  
- ✅ E2E tests run on release APK
- ✅ All tests pass (no ProGuard breakage)
- ✅ No crashes during test execution
- ✅ UI interactions work correctly

### Configuration Validation
- ✅ Package name correct
- ✅ Version code/name set
- ✅ Target SDK >= 33 (Play Store requirement)
- ✅ Minimum SDK appropriate
- ✅ Permissions reasonable

### Size/Quality Validation
- ✅ APK size reasonable (< 100MB ideal)
- ✅ No debug symbols in release
- ✅ Resources optimized
- ✅ DEX count reasonable

## Prerequisites

- Release build configured (`android-release-build-setup`)
- E2E tests created (`android-e2e-testing-setup`)
- Signing keystore available
- Device or emulator connected (for full validation)

## After Running This Command

**If Validation Passes:**
```
✅ Release Build Validation PASSED

Ready for Play Store deployment!

Next steps:
  1. Save ProGuard mapping file: app/build/outputs/mapping/release/mapping.txt
  2. Upload to Play Console or use android-playstore-publishing
  3. Keep mapping file for crash deobfuscation
```

**If Validation Fails:**
```
❌ Release Build Validation FAILED

Issues found:
  - Tests failed on release build
  - ProGuard removed required class: com.example.SomeClass

Fix:
  1. Add keep rule to proguard-rules.pro:
     -keep class com.example.SomeClass { *; }
  2. Rebuild and re-validate
```

## Validation Report

Generates detailed report with:

**Build Status:**
- APK/AAB build success/failure
- Build times and sizes
- MD5 hashes

**Test Results:**
- Total tests, passed, failed
- Specific test failures
- Test execution time

**Configuration:**
- SDK versions
- ProGuard/R8 status
- Signing details

**APK Analysis:**
- Size breakdown (DEX, resources, libs)
- Permissions list
- Large files
- Method count

**Issues:**
- Critical issues (must fix)
- Warnings (should review)
- Recommendations

## Common Issues Caught

### 1. ProGuard Breaking Functionality
**Symptom:** Tests pass on debug, fail on release

**Cause:** ProGuard removed or obfuscated required classes

**Fix:**
```proguard
# In proguard-rules.pro
-keep class com.example.RequiredClass { *; }
```

### 2. Missing Mapping File
**Symptom:** Mapping file not found

**Cause:** ProGuard not enabled

**Fix:**
```kotlin
// In build.gradle.kts
release {
    isMinifyEnabled = true  // Must be true
}
```

### 3. Invalid Signature
**Symptom:** Signature verification fails

**Cause:** Using debug keystore or wrong passwords

**Fix:** Check signing configuration and passwords

### 4. APK Too Large
**Symptom:** APK > 100MB

**Fix:**
```kotlin
release {
    isShrinkResources = true  // Enable resource shrinking
}
```

## Validation Levels

### Quick Validation (Faster)
- Build APK/AAB
- Check signing
- Verify mapping file
- Skip E2E tests
- **Time:** ~2-5 minutes

### Full Validation (Recommended)
- Everything in quick validation
- Run E2E tests on release
- Comprehensive APK analysis
- **Time:** ~10-20 minutes

## CI/CD Integration

### GitHub Actions Workflow

Created workflow validates every release build:
- Runs on pushes to main/release branches
- Runs on version tags (v*)
- Blocks deployment if validation fails
- Uploads artifacts and reports

**Workflow:** `.github/workflows/release-validation.yml`

### Artifacts Uploaded
- Release APK
- Release AAB
- ProGuard mapping file
- Test results
- Validation report

## Integration with Other Skills

### Prerequisites:
- `android-release-build-setup` - Provides signing and ProGuard config
- `android-e2e-testing-setup` - Provides tests to run

### Used By:
- `android-playstore-publishing` - Only deploys validated builds
- `android-playstore-pipeline` - Validation is part of pipeline

## Best Practices

1. **Always validate before deploying**
   - Never skip validation
   - Even for hotfixes

2. **Run full validation for releases**
   - Quick validation for development
   - Full validation before Play Store

3. **Save mapping files**
   - Keep for every release
   - Upload to Play Console
   - Store securely for crash reports

4. **Fix all critical issues**
   - Don't ignore test failures
   - ProGuard issues will cause production crashes

5. **Review warnings**
   - Address size warnings
   - Check permission warnings
   - Review target SDK warnings

## Troubleshooting

**"Build succeeds but tests fail"**
→ ProGuard issue - add keep rules for failing classes

**"Mapping file not found"**
→ Check `isMinifyEnabled = true` in release buildType

**"Signature verification fails"**
→ Using wrong keystore or incorrect passwords

**"APK won't install on device"**
→ Check minimum SDK matches device
→ Uninstall previous version first

**"Tests pass locally but fail in CI"**
→ Check emulator API level matches
→ Ensure animations disabled in CI

## Security Notes

1. **Keystore Protection:**
   - Use local dev keystore for validation
   - Production keystore only in CI/CD
   - Never commit keystores

2. **Mapping File Security:**
   - Don't commit to public repos
   - Store securely (encrypted)
   - Keep for each release version

3. **Build Artifacts:**
   - Don't commit APK/AAB files
   - Clean up after validation
   - Secure CI/CD artifact storage

## Skill Reference

This command uses the skill at:
`~/.claude/skills/user/devtools/android-release-validation/SKILL.md`

For detailed implementation, troubleshooting, and technical details, refer to the skill documentation.

## Related Commands

- `/devtools:android-release-setup` - Setup release builds (prerequisite)
- `/devtools:android-e2e-tests` - Setup tests (prerequisite)
- `/devtools:android-playstore-publish` - Deploy validated builds
- `/devtools:android-playstore-pipeline` - Complete pipeline

## Example Session

```
User: /devtools:android-release-validate

Claude: I'll validate your Android release build.

Validation type:
  1. Quick (build only, ~5 min)
  2. Full (includes E2E tests, ~15 min)
→ 2

Validate APK, AAB, or both?
→ both

Using local dev keystore for validation.

Step 1/10: Cleaning build...
✓ Build cleaned

Step 2/10: Building release APK...
✓ APK built successfully (15.3 MB) in 45s

Step 3/10: Building release AAB...
✓ AAB built successfully (14.8 MB) in 38s

Step 4/10: Validating signing...
✓ APK properly signed
✓ Using SHA256withRSA algorithm
✓ Certificate valid until 2050

Step 5/10: Checking ProGuard mapping...
✓ Mapping file generated (245 KB)

Step 6/10: Analyzing APK...
✓ Package: com.example.myapp
✓ Version: 1.0.0 (1)
✓ Target SDK: 34 ✓
✓ No debug symbols
✓ Size breakdown: DEX 45%, Resources 35%, Other 20%

Step 7/10: Running E2E tests on release...
✓ All 12 tests passed
✓ No crashes detected

Step 8/10: Checking permissions...
✓ 8 permissions (all appropriate)

Step 9/10: Generating report...
✓ Report: validation-report.md

Step 10/10: Summary...

✅ VALIDATION PASSED

Release build is production-ready!

Artifacts:
  APK: app/build/outputs/apk/release/app-release.apk (15.3 MB)
  AAB: app/build/outputs/bundle/release/app-release.aab (14.8 MB)
  Mapping: app/build/outputs/mapping/release/mapping.txt (245 KB)

Next: Upload to Play Store or use /devtools:android-playstore-publish
```

## Notes

- Validation catches ~80% of production issues before deployment
- Most critical: ProGuard breaking functionality (tests catch this!)
- Always save mapping file - you'll need it for crash reports
- Size warnings are important - large APKs have lower install rates
