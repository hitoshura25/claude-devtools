---
name: android-proguard-setup
description: Configure ProGuard/R8 for Android release builds with safe defaults
category: android
version: 1.0.0
inputs:
  - project_path: Path to Android project
outputs:
  - app/proguard-rules.pro
  - Updated app/build.gradle.kts with minification enabled
verify: "grep 'isMinifyEnabled = true' app/build.gradle.kts && test -f app/proguard-rules.pro"
---

# Android ProGuard/R8 Setup

Configures ProGuard/R8 code minification and resource shrinking with safe default rules.

## Prerequisites

- Android project with Gradle
- Kotlin DSL (build.gradle.kts)

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| project_path | Yes | . | Android project root |

## Process

### Step 1: Create ProGuard Rules File

Create or update `app/proguard-rules.pro` with safe defaults:

```bash
cat > app/proguard-rules.pro << 'EOF'
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
EOF
```

**Note:** If `proguard-rules.pro` already exists, ask the user if they want to:
- Replace with safe defaults
- Append safe defaults to existing rules
- Keep existing rules as-is

### Step 2: Enable Minification in build.gradle.kts

Update `app/build.gradle.kts` to enable ProGuard/R8:

```kotlin
android {
    // ... existing config ...

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

**Detection logic:**
- Check if `buildTypes.release` already exists
- Check if `isMinifyEnabled` is already set
- Preserve existing `proguardFiles` if present, append if needed

## Verification

**MANDATORY:** Run these commands:

```bash
# Verify ProGuard rules file exists
test -f app/proguard-rules.pro && echo "✓ ProGuard rules exist"

# Verify minification is enabled
grep "isMinifyEnabled = true" app/build.gradle.kts && echo "✓ Minification enabled"

# Verify resource shrinking is enabled
grep "isShrinkResources = true" app/build.gradle.kts && echo "✓ Resource shrinking enabled"
```

**Expected output:**
- ✓ ProGuard rules exist
- ✓ Minification enabled
- ✓ Resource shrinking enabled

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| ProGuard rules | app/proguard-rules.pro | Safe default keep rules |
| Build config | app/build.gradle.kts | Minification enabled |

## Troubleshooting

### "Build fails with ProGuard error"
**Cause:** ProGuard removed required classes
**Fix:** Add keep rules for the failing classes to proguard-rules.pro

### "App crashes on release but not debug"
**Cause:** ProGuard obfuscated code that uses reflection
**Fix:** Add keep rules for classes used via reflection

## Common Library Keep Rules

If using specific libraries, add these rules:

**Gson:**
```proguard
-keepattributes Signature
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
```

**Retrofit:**
```proguard
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}
```

**Room:**
```proguard
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
```

## Completion Criteria

- [ ] `app/proguard-rules.pro` exists with safe defaults
- [ ] `isMinifyEnabled = true` in app/build.gradle.kts
- [ ] `isShrinkResources = true` in app/build.gradle.kts
- [ ] ProGuard rules syntax is valid
