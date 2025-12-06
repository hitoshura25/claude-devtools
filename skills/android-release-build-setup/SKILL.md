---
name: android-release-build-setup
description: Complete Android release build configuration including keystore generation, ProGuard/R8 setup, and signing configuration
category: android
version: 1.0.0
---

# Android Release Build Setup

This skill configures everything needed for Android release builds with proper security and optimization.

## What This Does

1. **Dual Keystore Strategy (Security Best Practice)**
   - Generates production keystore (for CI/CD only, never on developer machines)
   - Generates local development keystore (for testing release builds locally)
   - Ensures production keystore stays secure in CI/CD environment
   - Each developer has unique local keystore (zero risk of production keystore leak)

2. **ProGuard/R8 Configuration**
   - Enables code minification and obfuscation
   - Enables resource shrinking
   - Generates safe default proguard-rules.pro
   - Configures mapping file output for crash deobfuscation

3. **Release Build Configuration**
   - Configures release buildType in build.gradle.kts
   - Sets up dual-source signing config (environment variables + gradle.properties)
   - Configures build optimizations
   - Sets up validation to catch missing signing config early

## Prerequisites

- Android project with Gradle
- JDK installed (for keytool command)
- Project uses Kotlin DSL (build.gradle.kts)

## Parameters

None required - skill will detect project configuration and prompt for necessary information.

## Step-by-Step Process

### Step 1: Analyze Project

First, analyze the Android project structure:

```kotlin
// Read app/build.gradle.kts to understand current configuration
// Check for:
// - Package name / namespace
// - Current SDK versions
// - Existing signing configuration
// - ProGuard/R8 status
```

**Ask the user:**
- "What is your project path?" (if not obvious from context)
- Confirm detected package name
- Confirm detected module path (usually "app")

### Step 2: Generate Production Keystore

**CRITICAL SECURITY NOTE:** This keystore is for CI/CD ONLY. Never store on developer machines.

Generate production keystore with secure parameters:

```bash
keytool -genkeypair -v \
  -keystore production-release.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass [GENERATED_SECURE_PASSWORD] \
  -keypass [GENERATED_SECURE_PASSWORD] \
  -dname "CN=Android Release, OU=Release, O=[COMPANY], L=[CITY], ST=[STATE], C=[COUNTRY]"
```

**Parameters:**
- Alias: "upload" (Google Play standard)
- Validity: 10,000 days (~27 years)
- Key size: 2048 bits minimum
- Auto-generate secure passwords (16+ characters)

**Ask the user for Distinguished Name (DN) fields:**
- Organization (O): Company name
- Organizational Unit (OU): "Release" (default)
- Common Name (CN): "Android Release" (default)
- Location (L): City (optional)
- State (ST): State/Province (optional)
- Country (C): 2-letter country code (optional)

**Output:**
1. Save keystore to: `<project>/keystores/production-release.jks`
2. Create `<project>/keystores/KEYSTORE_INFO.txt` with:
   ```
   Production Keystore Information
   ===============================
   Location: production-release.jks
   Alias: upload
   Store Password: [PASSWORD]
   Key Password: [PASSWORD]
   
   SECURITY WARNING:
   - This file contains sensitive credentials
   - Never commit to version control
   - Store securely in password manager
   - Use for CI/CD GitHub Secrets only
   
   GitHub Secrets Setup:
   - SIGNING_KEY_STORE_BASE64: [run: base64 -w 0 production-release.jks]
   - SIGNING_KEY_ALIAS: upload
   - SIGNING_STORE_PASSWORD: [PASSWORD]
   - SIGNING_KEY_PASSWORD: [PASSWORD]
   ```
3. Base64 encode the keystore for GitHub Secrets

### Step 3: Generate Local Development Keystore

Generate a separate keystore for local testing of release builds:

```bash
keytool -genkeypair -v \
  -keystore local-dev-release.jks \
  -alias local-dev \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10950 \
  -storepass [GENERATED_SECURE_PASSWORD] \
  -keypass [GENERATED_SECURE_PASSWORD] \
  -dname "CN=Local Development, OU=Development, O=Local, L=Local, ST=Local, C=US"
```

**Output:**
1. Save keystore to: `<project>/keystores/local-dev-release.jks`
2. Update ~/.gradle/gradle.properties with:
   ```properties
   SIGNING_KEY_STORE_PATH=<absolute_path>/keystores/local-dev-release.jks
   SIGNING_KEY_ALIAS=local-dev
   SIGNING_STORE_PASSWORD=[PASSWORD]
   SIGNING_KEY_PASSWORD=[PASSWORD]
   ```

**Ask permission before modifying ~/.gradle/gradle.properties**

### Step 4: Configure ProGuard/R8

Create or update `app/proguard-rules.pro` with safe defaults:

```proguard
# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in the Android SDK.

# Keep line numbers for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# Hide the original source file name
-renamesourcefileattribute SourceFile

# Keep data classes and their fields
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep custom views
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
```

**If project uses specific libraries, add keep rules:**
- Ask: "Are you using Gson, Retrofit, Room, or other reflection-heavy libraries?"
- Add appropriate keep rules based on response

### Step 5: Update build.gradle.kts

Add signing configuration to `app/build.gradle.kts`:

```kotlin
android {
    namespace = "com.example.app" // Keep existing
    compileSdk = 34 // Keep existing

    defaultConfig {
        // Keep existing config
    }

    // ADD THIS SECTION
    signingConfigs {
        create("release") {
            // Priority: environment variables (CI/CD) > gradle.properties (local dev)
            val keystorePath = System.getenv("SIGNING_KEY_STORE_PATH")
                ?: project.findProperty("SIGNING_KEY_STORE_PATH")?.toString()
            val storePass = System.getenv("SIGNING_STORE_PASSWORD")
                ?: project.findProperty("SIGNING_STORE_PASSWORD")?.toString()
            val alias = System.getenv("SIGNING_KEY_ALIAS")
                ?: project.findProperty("SIGNING_KEY_ALIAS")?.toString()
            val keyPass = System.getenv("SIGNING_KEY_PASSWORD")
                ?: project.findProperty("SIGNING_KEY_PASSWORD")?.toString()

            if (keystorePath != null && storePass != null && alias != null && keyPass != null) {
                storeFile = file(keystorePath)
                storePassword = storePass
                keyAlias = alias
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Validate signing config only when building release variants
    tasks.matching { it.name.contains("Release") }.configureEach {
        doFirst {
            val releaseConfig = android.signingConfigs.getByName("release")
            if (releaseConfig.storeFile == null) {
                throw GradleException(
                    """
                    Release signing not configured!

                    For CI/CD: Set environment variables:
                      - SIGNING_KEY_STORE_PATH
                      - SIGNING_STORE_PASSWORD
                      - SIGNING_KEY_ALIAS
                      - SIGNING_KEY_PASSWORD

                    For local development: Add to ~/.gradle/gradle.properties:
                      SIGNING_KEY_STORE_PATH=/path/to/local-dev-release.jks
                      SIGNING_STORE_PASSWORD=your-password
                      SIGNING_KEY_ALIAS=local-dev
                      SIGNING_KEY_PASSWORD=your-password
                    """.trimIndent()
                )
            }
        }
    }
}
```

**Detection logic:**
- Check if `signingConfigs` already exists - if yes, update the release config
- Check if `isMinifyEnabled` is already true - if yes, keep as is
- Check if custom proguard files exist - if yes, preserve them

### Step 6: Update .gitignore

Add to `.gitignore` to prevent committing sensitive files:

```gitignore
# Keystores (CRITICAL - never commit!)
keystores/
*.jks
*.keystore
KEYSTORE_INFO.txt

# Gradle properties with secrets
gradle.properties

# ProGuard mapping files (keep for debugging, but don't commit)
app/build/outputs/mapping/
```

### Step 7: Create Template Files

Create `gradle.properties.template` in project root:

```properties
# Template for local development signing configuration
# Copy this to gradle.properties (gitignored) and fill in values

# Path to your LOCAL development keystore (NOT production!)
SIGNING_KEY_STORE_PATH=/path/to/keystores/local-dev-release.jks

# Local development keystore credentials
SIGNING_KEY_ALIAS=local-dev
SIGNING_STORE_PASSWORD=your-local-dev-password
SIGNING_KEY_PASSWORD=your-local-dev-password

# IMPORTANT SECURITY NOTES:
# 1. This is for LOCAL testing of release builds ONLY
# 2. NEVER use production keystore locally
# 3. Production keystore lives ONLY in CI/CD (GitHub Secrets)
# 4. Each developer should have their own unique local keystore
```

### Step 8: Verify Configuration (MANDATORY)

**CRITICAL: This step is MANDATORY and must pass before completing the skill.**

Test the setup with actual builds:

```bash
# 1. Test that debug build still works (sanity check)
./gradlew assembleDebug

# 2. REQUIRED: Build release APK to verify everything works
./gradlew assembleRelease

# 3. REQUIRED: Verify the release APK was actually created
ls -lh app/build/outputs/apk/release/app-release.apk

# 4. REQUIRED: Verify ProGuard mapping file was generated
ls -lh app/build/outputs/mapping/release/mapping.txt

# 5. REQUIRED: Verify APK is signed correctly
jarsigner -verify -verbose -certs app/build/outputs/apk/release/app-release.apk
```

**Expected output:**
- Debug build: ✓ Success
- Release build: ✓ Success (NOT dry-run - actual build)
- APK file exists: ✓ app/build/outputs/apk/release/app-release.apk
- Mapping file exists: ✓ app/build/outputs/mapping/release/mapping.txt  
- APK verification: ✓ "jar verified"

**If ANY of these checks fail:**
1. DO NOT mark the skill as complete
2. Investigate the error
3. Fix the issue
4. Re-run all verification steps
5. Only complete when ALL checks pass

**Common Failures:**
- "Signing config not found" → gradle.properties not configured correctly
- "ProGuard error" → Add keep rules to proguard-rules.pro
- "Build failed" → Check error logs, fix syntax/configuration
- "Mapping file missing" → Verify isMinifyEnabled = true

### Step 9: Generate Summary Report

Provide comprehensive summary:

```
✅ Android Release Build Setup Complete!

📦 Keystores Generated:
  Production: keystores/production-release.jks
    - Alias: upload
    - For CI/CD GitHub Secrets ONLY
    - Passwords in: keystores/KEYSTORE_INFO.txt
  
  Local Dev: keystores/local-dev-release.jks
    - Alias: local-dev
    - For local testing only
    - Configured in: ~/.gradle/gradle.properties

🔒 ProGuard/R8 Configuration:
  ✓ Minification enabled (isMinifyEnabled = true)
  ✓ Resource shrinking enabled
  ✓ Safe default rules created: app/proguard-rules.pro
  ✓ Mapping file output configured

⚙️  Build Configuration:
  ✓ Signing config added to app/build.gradle.kts
  ✓ Dual-source strategy (env vars + gradle.properties)
  ✓ Validation on release builds
  ✓ Template created: gradle.properties.template

🛡️  Security:
  ✓ .gitignore updated (keystores, secrets excluded)
  ✓ Production keystore never touches developer machines
  ✓ Each developer has unique local keystore
  ✓ Clear separation: local dev vs production

📋 Next Steps:

  For Local Development:
    1. Credentials already in ~/.gradle/gradle.properties
    2. Test release build: ./gradlew assembleRelease
    3. Install on device: ./gradlew installRelease
  
  For CI/CD (GitHub Actions):
    1. Add GitHub Secrets (see KEYSTORE_INFO.txt):
       - SIGNING_KEY_STORE_BASE64
       - SIGNING_KEY_ALIAS
       - SIGNING_STORE_PASSWORD  
       - SIGNING_KEY_PASSWORD
    2. Use android-playstore-publishing skill to generate workflow
  
  For ProGuard:
    1. Test release build thoroughly
    2. If libraries break, add keep rules to proguard-rules.pro
    3. Use mapping file for crash deobfuscation

⚠️  CRITICAL REMINDERS:
  - NEVER commit keystores to git
  - NEVER use production keystore locally
  - ALWAYS back up production keystore securely
  - ALWAYS store passwords in password manager
  - Loss of production keystore = cannot update app on Play Store!
```

## Error Handling

### Keystore Generation Fails
- Check JDK is installed: `java -version`
- Check keytool is available: `keytool -help`
- Ensure output directory is writable

### Build Configuration Fails
- Verify build.gradle.kts syntax (Kotlin DSL)
- Check for conflicting signing configs
- Ensure ProGuard file syntax is valid

### ProGuard Breaks Build
- Review error messages for missing keep rules
- Check library documentation for ProGuard rules
- Test incrementally: enable minification, test, add rules as needed

## Security Best Practices

1. **Never commit keystores** - Use .gitignore
2. **Separate dev and production** - Different keystores for different purposes
3. **Back up production keystore** - Multiple secure locations
4. **Use strong passwords** - Auto-generated, stored in password manager
5. **Minimal access** - Production keystore only in CI/CD environment
6. **Regular rotation** - Consider rotating service accounts (not keystores - those must stay the same!)

## Integration with Other Skills

This skill is prerequisite for:
- `android-e2e-testing-setup` - Tests release builds
- `android-release-validation` - Validates signed APK/AAB
- `android-playstore-publishing` - Uses keystore for CI/CD workflow
- `android-playstore-pipeline` - Orchestrates full setup

## Troubleshooting

### "keytool not found"
Install JDK:
- Ubuntu/Debian: `sudo apt install openjdk-17-jdk`
- macOS: `brew install openjdk@17`
- Windows: Download from https://adoptium.net/

### "Gradle build fails with ProGuard error"
1. Check app logs for specific class/method causing issue
2. Add keep rule for that class
3. Check library documentation for required ProGuard rules
4. Common libraries and their rules are in template

### "Cannot sign release build"
1. Check ~/.gradle/gradle.properties has correct paths
2. Verify keystore file exists at specified path
3. Verify passwords are correct
4. Test keystore with: `keytool -list -v -keystore <path>`

### "Build succeeds but app crashes on release"
ProGuard likely removed required code:
1. Check crash logs for obfuscated class names
2. Use mapping file to deobfuscate: `retrace.sh mapping.txt stacktrace.txt`
3. Add keep rules for affected classes
4. Common culprits: reflection, serialization, native code

## Files Created/Modified

**Created:**
- `keystores/production-release.jks` - Production keystore (gitignored)
- `keystores/local-dev-release.jks` - Local dev keystore (gitignored)
- `keystores/KEYSTORE_INFO.txt` - Production credentials (gitignored)
- `app/proguard-rules.pro` - ProGuard configuration (or updated if exists)
- `gradle.properties.template` - Template for local setup (committed)

**Modified:**
- `app/build.gradle.kts` - Added signing config, ProGuard, release buildType
- `.gitignore` - Added keystore and secret patterns
- `~/.gradle/gradle.properties` - Added local dev keystore config (user's global gradle.properties)

**Not Modified (Preserved):**
- Existing SDK versions (compileSdk, targetSdk, minSdk)
- Existing dependencies
- Existing build variants
- Existing ProGuard rules (appended, not replaced)

## Completion Criteria (ALL MUST PASS)

Do NOT mark this skill as complete unless ALL of the following are verified:

✅ **Keystores generated and secured**
  - [ ] production-release.jks exists in keystores/
  - [ ] local-dev-release.jks exists in keystores/
  - [ ] KEYSTORE_INFO.txt created with passwords
  - [ ] keystores/ added to .gitignore

✅ **ProGuard configured**
  - [ ] proguard-rules.pro exists with safe defaults
  - [ ] isMinifyEnabled = true in build.gradle.kts
  - [ ] isShrinkResources = true in build.gradle.kts

✅ **Signing configured**
  - [ ] signingConfigs.release exists in build.gradle.kts
  - [ ] Release buildType uses signingConfig
  - [ ] gradle.properties configured (local) OR environment variables set (CI)

✅ **MANDATORY: Build verification**
  - [ ] `./gradlew assembleDebug` succeeds
  - [ ] `./gradlew assembleRelease` succeeds
  - [ ] app/build/outputs/apk/release/app-release.apk exists
  - [ ] app/build/outputs/mapping/release/mapping.txt exists
  - [ ] `jarsigner -verify` confirms APK is signed correctly

✅ **Documentation created**
  - [ ] gradle.properties.template created
  - [ ] KEYSTORE_INFO.txt contains all necessary info

**If ANY checkbox is unchecked, the skill is NOT complete.**

## Expected Outcomes

After running this skill:

✅ **Can build release APK/AAB locally** - VERIFIED by assembleRelease
✅ **Can build release in CI/CD** - Configuration ready
✅ **ProGuard enabled and working** - VERIFIED by successful build with mapping
✅ **Production keystore secured** - Never on developer machines
✅ **Clear error messages** - Validation catches misconfiguration
✅ **Ready for Play Store** - Signing verified

## Next Skills (Dependencies)

This skill is a PREREQUISITE for:
- `android-e2e-testing-setup` - Requires working release builds to test against
- `android-release-validation` - Validates the release build this skill creates
- `android-playstore-publishing` - Uses the signing configuration

Do NOT run those skills until this skill's completion criteria are met.

## References

- [Android App Signing Documentation](https://developer.android.com/studio/publish/app-signing)
- [ProGuard Manual](https://www.guardsquare.com/manual/configuration/usage)
- [R8 Shrinking Guide](https://developer.android.com/build/shrink-code)
- [Google Play Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
