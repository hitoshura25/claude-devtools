---
description: Setup complete Android release build configuration with keystores, ProGuard, and signing
---

# Android Release Build Setup

Set up complete release build configuration for Android projects including dual keystore strategy, ProGuard/R8 optimization, and signing configuration.

## What This Command Does

Configures everything needed for production-ready Android releases:
- ✅ Dual keystore generation (production + local development)
- ✅ ProGuard/R8 code minification and optimization
- ✅ Release build type configuration
- ✅ Signing configuration (CI/CD + local development)
- ✅ Security best practices (gitignore, separation of concerns)

## Usage

```bash
/devtools:android-release-setup
```

## Interactive Setup

The command will:
1. Detect your Android project configuration
2. Ask for organization details (for keystore DN)
3. Generate secure passwords automatically
4. Create both production and local development keystores
5. Configure ProGuard/R8 with safe defaults
6. Update build.gradle.kts with signing configuration
7. Configure .gitignore to prevent committing secrets
8. Provide complete setup summary and next steps

## What Gets Created

**Keystores:**
- `keystores/production-release.jks` - For CI/CD only (NEVER on dev machines)
- `keystores/local-dev-release.jks` - For local testing only
- `keystores/KEYSTORE_INFO.txt` - Production credentials (NEVER commit!)

**Configuration Files:**
- `app/proguard-rules.pro` - ProGuard optimization rules
- `gradle.properties.template` - Template for local setup
- Updated `app/build.gradle.kts` - Signing and release configuration
- Updated `.gitignore` - Keystore and secrets exclusions

**Global Configuration:**
- `~/.gradle/gradle.properties` - Local dev keystore config (asks permission first)

## Security Model

**Production Keystore:**
- Generated but NEVER used locally
- Base64 encoded for GitHub Secrets
- Only accessed in CI/CD environment
- Backed up in multiple secure locations

**Local Development Keystore:**
- Each developer has unique keystore
- Used only for local testing of release builds
- Different from production (zero risk of leaks)
- Configured in ~/.gradle/gradle.properties

## Prerequisites

- Android project with Gradle wrapper
- JDK installed (for keytool command)
- Kotlin DSL (build.gradle.kts)
- Write access to ~/.gradle/gradle.properties

## After Running This Command

**For Local Development:**
```bash
./gradlew assembleRelease   # Build release APK
./gradlew installRelease    # Install on connected device
```

**For CI/CD:**
1. Add GitHub Secrets (values in KEYSTORE_INFO.txt)
2. Run `/devtools:android-playstore-publish` to generate workflow

**For Testing:**
```bash
./gradlew assembleDebug     # Should still work (no changes)
./gradlew assembleRelease   # Should build with local keystore
```

## Skill Reference

This command uses the skill at:
`~/.claude/skills/user/devtools/android-release-build-setup/SKILL.md`

For detailed implementation steps, troubleshooting, and technical details, refer to the skill documentation.

## Related Commands

- `/devtools:android-e2e-tests` - Setup E2E testing (run after this)
- `/devtools:android-release-validate` - Validate release builds
- `/devtools:android-playstore-publish` - Generate GitHub workflow
- `/devtools:android-playstore-pipeline` - Complete end-to-end setup

## Common Issues

**"keytool not found"**
→ Install JDK: `brew install openjdk@17` (macOS) or `sudo apt install openjdk-17-jdk` (Linux)

**"Permission denied" for ~/.gradle/gradle.properties**
→ Command asks permission before modifying - approve when prompted

**"Build fails with ProGuard error"**
→ Review error message and add keep rules to proguard-rules.pro

## Example Session

```
User: /devtools:android-release-setup

Claude: I'll help you set up Android release builds. Let me analyze your project first.

Detected:
- Project: ~/my-android-app
- Package: com.example.myapp
- Module: app
- SDK: targetSdk 34, minSdk 26

For the production keystore, I need some organization information:
- Organization (company name): 
→ MyCompany Inc

- Country code (2 letters, optional): 
→ US

Generating keystores...
✓ Production keystore created: keystores/production-release.jks
✓ Local dev keystore created: keystores/local-dev-release.jks

May I update ~/.gradle/gradle.properties with local dev credentials?
→ Yes

✓ ProGuard rules created: app/proguard-rules.pro
✓ Build configuration updated: app/build.gradle.kts
✓ Security configured: .gitignore updated

Setup complete! 
Production credentials: keystores/KEYSTORE_INFO.txt
Test locally: ./gradlew assembleRelease
```

## Notes

- Auto-generates secure 16+ character passwords
- Validates keystore creation with keytool
- Preserves existing ProGuard rules (appends, doesn't replace)
- Detects existing signing config (updates instead of duplicating)
- Works with both new and existing Android projects
