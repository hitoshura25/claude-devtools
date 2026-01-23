---
name: lint-kotlin
description: Use when checking code quality on Kotlin or Android files before commit
---

# Kotlin/Android Linting

## Overview

Run ktlint + Android Lint on Kotlin files. All errors in modified files must be fixed.

## Tool Stack

| Tool | Purpose | Config |
|------|---------|--------|
| ktlint | Code style (Kotlin official style guide) | `.editorconfig` |
| Android Lint | Android-specific issues | `lint.xml` |
| Detekt | Static analysis (optional) | `detekt.yml` |

## The Rule

```
ALL LINT ERRORS IN MODIFIED FILES MUST BE FIXED
No "document for later". No "pre-existing issues".
You touch it, you own it.
```

## Process

### 1. Check Setup

```bash
# Verify ktlint is configured in Gradle
grep -q "ktlint" build.gradle.kts || grep -q "ktlint" app/build.gradle.kts
```

**Not configured?** See `references/setup.md`

### 2. Run ktlint Check

```bash
./gradlew ktlintCheck
```

### 3. Run Android Lint

```bash
./gradlew lint
# Or for specific variant
./gradlew lintDebug
```

### 4. Fix ktlint Issues

```bash
# Auto-format
./gradlew ktlintFormat

# Manually fix remaining issues
```

### 5. Fix Android Lint Issues

Review `app/build/reports/lint-results-debug.html` and fix issues in code.

### 6. Verify Clean

```bash
./gradlew ktlintCheck lint
# Expected: BUILD SUCCESSFUL
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Pre-existing errors, not mine" | You modified the file. Fix ALL errors in it. |
| "Just formatting, not important" | ktlint enforces official Kotlin style. Fix it. |
| "Android Lint is too strict" | Lint catches real bugs. Fix or suppress with justification. |
| "Will fix in follow-up PR" | No. Fix now. Lint is not negotiable. |
| "Detekt is overkill" | Static analysis catches bugs early. Run it. |

## Red Flags - STOP

- Disabling ktlint or lint in `build.gradle.kts` to hide errors
- Adding `@Suppress` without justification comment
- Claiming "lint passed" without running Gradle tasks
- Skipping Android Lint because "it's slow"

**If you catch yourself doing any of these: STOP. Fix properly.**

## Inline Suppression (When Necessary)

### ktlint

```kotlin
// ktlint-disable no-wildcard-imports - Legacy code requires wildcard
import android.widget.*
```

### Android Lint

```kotlin
@Suppress("MagicNumber") // Port numbers are inherently magic
const val DEFAULT_PORT = 8080
```

Or in XML:

```xml
<LinearLayout
    tools:ignore="ContentDescription"
    ... />
```

**Requirements for suppression:**
- Specific rule/check name
- Justification comment explaining WHY
- Narrowest scope possible

## Verification

```bash
./gradlew ktlintCheck lint
# Expected: BUILD SUCCESSFUL with no warnings
```

## References

- `references/setup.md` - ktlint and Android Lint setup
- `references/detekt.md` - Optional Detekt configuration
