# Android Signing Configuration

## Overview

Android apps must be signed with a keystore for release. Google Play App Signing is recommended (Google manages the signing key, you keep upload key).

## Keystore Generation

### Generate Upload Keystore

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload-key \
  -storetype JKS
```

Follow prompts for:
- Keystore password
- Key password
- Name (CN)
- Organization (O)
- Country (C)

**IMPORTANT:** Save passwords securely. Lost = can't update app.

### File Locations

```
# Local development (DO NOT commit)
upload-keystore.jks

# CI/CD
# Store as base64-encoded secret
base64 upload-keystore.jks > keystore.b64
```

## Gradle Configuration

### Create keystore.properties

`keystore.properties` (add to .gitignore):

```properties
storeFile=../upload-keystore.jks
storePassword=your_store_password
keyAlias=upload-key
keyPassword=your_key_password
```

### Configure build.gradle.kts

```kotlin
import java.util.Properties

// Load keystore properties
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    signingConfigs {
        create("release") {
            // From properties file (local)
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
            // From environment (CI)
            else if (System.getenv("KEYSTORE_FILE") != null) {
                storeFile = file(System.getenv("KEYSTORE_FILE"))
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

## CI/CD Setup

### GitHub Actions Secrets

Set these secrets:
- `KEYSTORE_BASE64` - Base64-encoded keystore file
- `KEYSTORE_PASSWORD` - Keystore password
- `KEY_ALIAS` - Key alias (e.g., "upload-key")
- `KEY_PASSWORD` - Key password

### Workflow Configuration

```yaml
- name: Decode Keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > upload-keystore.jks
    
- name: Build Release
  env:
    KEYSTORE_FILE: upload-keystore.jks
    KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
    KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
    KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
  run: ./gradlew bundleRelease
```

## Play App Signing

### Enable Play App Signing

1. Go to Play Console → Release → Setup → App signing
2. Choose "Use Google-generated key"
3. Upload your upload key certificate

### Export Upload Certificate

```bash
keytool -export \
  -alias upload-key \
  -keystore upload-keystore.jks \
  -file upload-cert.pem \
  -rfc
```

Upload `upload-cert.pem` to Play Console.

## Security Best Practices

1. **Never commit keystores** - Add to .gitignore
2. **Never commit passwords** - Use environment variables
3. **Backup keystores securely** - Lost keystore = can't update app
4. **Use Play App Signing** - Google manages signing key
5. **Rotate upload keys** if compromised - Play Console allows this
6. **Use different keystores** for debug/release

## Verification

```bash
# Check keystore contents
keytool -list -v -keystore upload-keystore.jks

# Verify APK/AAB signature
apksigner verify --print-certs app-release.aab

# Check signing config in Gradle
./gradlew signingReport
```

## Troubleshooting

### "Keystore was tampered with"

Wrong password or corrupted file. Verify password and regenerate if needed.

### "No key with alias found"

Check alias name matches exactly:
```bash
keytool -list -keystore upload-keystore.jks
```

### "Signature mismatch" on Play Store

You're using different keystore than originally uploaded. If using Play App Signing, upload key may differ from app signing key (this is normal).
