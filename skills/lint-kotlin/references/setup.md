# Kotlin Lint Setup

## ktlint Setup

### Gradle Plugin (Recommended)

Add to root `build.gradle.kts`:

```kotlin
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0" apply false
}
```

Add to `app/build.gradle.kts`:

```kotlin
plugins {
    id("org.jlleitschuh.gradle.ktlint")
}

ktlint {
    version.set("1.2.1")
    android.set(true)
    outputToConsole.set(true)
    ignoreFailures.set(false)
    enableExperimentalRules.set(false)
    
    filter {
        exclude("**/generated/**")
        include("**/kotlin/**")
    }
}
```

### .editorconfig

Create `.editorconfig` in project root:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
insert_final_newline = true
trim_trailing_whitespace = true

[*.{kt,kts}]
indent_size = 4
max_line_length = 120

[*.{xml,json,yml,yaml}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false
```

## Android Lint Setup

Android Lint is included with Android Gradle Plugin. Configure in `app/build.gradle.kts`:

```kotlin
android {
    lint {
        // Treat errors as fatal (fail build)
        abortOnError = true
        
        // Treat warnings as errors in CI
        warningsAsErrors = System.getenv("CI") != null
        
        // Check all issues, not just default set
        checkAllWarnings = true
        
        // Generate HTML report
        htmlReport = true
        htmlOutput = file("build/reports/lint-results.html")
        
        // Baseline for legacy projects (optional)
        // baseline = file("lint-baseline.xml")
    }
}
```

### lint.xml (Optional - Customize Severity)

Create `app/lint.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<lint>
    <!-- Treat as error -->
    <issue id="HardcodedText" severity="error" />
    <issue id="MissingTranslation" severity="error" />
    
    <!-- Ignore in specific paths -->
    <issue id="UnusedResources">
        <ignore path="**/res/values/colors.xml" />
    </issue>
    
    <!-- Downgrade to warning -->
    <issue id="ObsoleteLintCustomCheck" severity="warning" />
</lint>
```

## Detekt Setup (Optional - Static Analysis)

Add to root `build.gradle.kts`:

```kotlin
plugins {
    id("io.gitlab.arturbosch.detekt") version "1.23.5" apply false
}
```

Add to `app/build.gradle.kts`:

```kotlin
plugins {
    id("io.gitlab.arturbosch.detekt")
}

detekt {
    buildUponDefaultConfig = true
    config.setFrom(files("$rootDir/config/detekt/detekt.yml"))
    baseline = file("$rootDir/config/detekt/baseline.xml")
}

dependencies {
    detektPlugins("io.gitlab.arturbosch.detekt:detekt-formatting:1.23.5")
}
```

Create `config/detekt/detekt.yml`:

```yaml
build:
  maxIssues: 0
  excludeCorrectable: false

complexity:
  active: true
  LongMethod:
    threshold: 60
  LongParameterList:
    functionThreshold: 6
    constructorThreshold: 7
  TooManyFunctions:
    thresholdInFiles: 15
    thresholdInClasses: 15

style:
  active: true
  MagicNumber:
    ignoreNumbers:
      - '-1'
      - '0'
      - '1'
      - '2'
    ignorePropertyDeclaration: true
    ignoreAnnotation: true
  MaxLineLength:
    maxLineLength: 120

naming:
  active: true
  FunctionNaming:
    functionPattern: '[a-z][a-zA-Z0-9]*'
```

## Verification

```bash
# ktlint check
./gradlew ktlintCheck

# ktlint format
./gradlew ktlintFormat

# Android Lint
./gradlew lint

# Detekt (if configured)
./gradlew detekt

# All at once
./gradlew ktlintCheck lint detekt
```

## CI Integration

Add to `.github/workflows/lint.yml`:

```yaml
name: Lint

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      
      - name: Run ktlint
        run: ./gradlew ktlintCheck
      
      - name: Run Android Lint
        run: ./gradlew lint
      
      - name: Upload Lint Report
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: lint-report
          path: app/build/reports/lint-results*.html
```
