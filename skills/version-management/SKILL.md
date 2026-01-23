---
name: version-management
description: Use when managing versions with git tags as source of truth across platforms
---

# Version Management

## Overview

Technology-agnostic version management using Git tags as source of truth, with platform adapters for Gradle, npm, and Python.

## The Rule

```
GIT TAGS ARE THE SOURCE OF TRUTH
Version files cache for fast builds.
Never manually edit version files.
```

## Semantic Versioning

```
MAJOR.MINOR.PATCH

MAJOR - Breaking changes
MINOR - New features, backwards compatible
PATCH - Bug fixes, backwards compatible
```

## Process

### 1. Check Current Version

```bash
# Get latest tag
git tag -l 'v*' | sort -V | tail -1

# Or use version script
./scripts/version-manager.sh latest
```

### 2. Generate Next Version

```bash
# Patch bump (1.0.0 → 1.0.1)
./scripts/version-manager.sh generate patch

# Minor bump (1.0.1 → 1.1.0)
./scripts/version-manager.sh generate minor

# Major bump (1.1.0 → 2.0.0)
./scripts/version-manager.sh generate major
```

### 3. Update Platform Files

**Gradle/Android:**
```bash
./scripts/gradle-version.sh update
# Updates version.properties
```

**npm:**
```bash
npm version patch  # or minor/major
# Updates package.json
```

**Python:**
```bash
# Update pyproject.toml manually or use setuptools_scm
```

### 4. Commit and Tag

```bash
VERSION=$(./scripts/version-manager.sh latest)
git add version.properties  # or package.json, pyproject.toml
git commit -m "chore: bump version to $VERSION"
git tag "v$VERSION"
git push origin main
git push origin "v$VERSION"
```

## Core Scripts

### version-manager.sh

Create `scripts/version-manager.sh`:

```bash
#!/bin/bash
set -euo pipefail

BASE_VERSION="${BASE_VERSION:-1.0}"
TAG_PREFIX="${TAG_PREFIX:-v}"

get_latest_version() {
    git tag -l "${TAG_PREFIX}*" 2>/dev/null |
        sed "s/^${TAG_PREFIX}//" |
        sort -V |
        tail -1 || echo "0.0.0"
}

bump_version() {
    local version="$1"
    local bump_type="${2:-patch}"
    
    IFS='.' read -r major minor patch <<< "$version"
    major="${major:-0}"; minor="${minor:-0}"; patch="${patch:-0}"
    
    case "$bump_type" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

generate_version() {
    local bump_type="${1:-patch}"
    local latest
    latest=$(get_latest_version)
    
    if [[ "$latest" == "0.0.0" ]]; then
        echo "${BASE_VERSION}.0"
    else
        bump_version "$latest" "$bump_type"
    fi
}

main() {
    local command="${1:-generate}"
    local arg="${2:-patch}"
    
    case "$command" in
        generate) generate_version "$arg" ;;
        latest)   get_latest_version ;;
        bump)     bump_version "$(get_latest_version)" "$arg" ;;
        *)        echo "Usage: $0 {generate|latest|bump} [patch|minor|major]" >&2; exit 1 ;;
    esac
}

main "$@"
```

### gradle-version.sh (Android)

Create `scripts/gradle-version.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/version-manager.sh"

semver_to_version_code() {
    local version="$1"
    IFS='.' read -r major minor patch <<< "$version"
    echo $((major * 1000000 + minor * 1000 + patch))
}

update_version_properties() {
    local version="$1"
    local version_code
    version_code=$(semver_to_version_code "$version")
    
    cat > version.properties << EOF
# Auto-generated - do not edit manually
VERSION_NAME=$version
VERSION_CODE=$version_code
EOF
    echo "Updated: VERSION_NAME=$version, VERSION_CODE=$version_code"
}

main() {
    local command="${1:-generate}"
    shift || true
    
    case "$command" in
        generate)
            generate_version "${1:-patch}"
            ;;
        update)
            local version="${1:-$(get_latest_version)}"
            update_version_properties "$version"
            ;;
        version-code)
            local version="${1:-$(get_latest_version)}"
            semver_to_version_code "$version"
            ;;
        *)
            echo "Usage: $0 {generate|update|version-code} [version]"
            exit 1
            ;;
    esac
}

main "$@"
```

## Platform Integration

### Gradle (Android)

`app/build.gradle.kts`:

```kotlin
import java.util.Properties

val versionProps = Properties().apply {
    val file = rootProject.file("version.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    defaultConfig {
        versionName = versionProps.getProperty("VERSION_NAME", "0.0.1-dev")
        versionCode = versionProps.getProperty("VERSION_CODE", "1")?.toIntOrNull() ?: 1
    }
}
```

### npm

Use npm's built-in versioning:
```bash
npm version patch  # Updates package.json and creates tag
```

### Python with setuptools_scm

`pyproject.toml`:
```toml
[tool.setuptools_scm]
write_to = "src/package/_version.py"
```

Version derived from git tags automatically.

## CI/CD Integration

### GitHub Actions

```yaml
- name: Get version from tag
  id: version
  run: |
    VERSION=${GITHUB_REF#refs/tags/v}
    echo "version=$VERSION" >> $GITHUB_OUTPUT

- name: Update version files
  run: ./scripts/gradle-version.sh update ${{ steps.version.outputs.version }}
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "I'll update version later" | Version must match tag. Update now. |
| "Manual edit is faster" | Scripts prevent errors. Use them. |
| "It's just a patch" | All versions go through the same process. |

## Red Flags - STOP

- Manually editing version files
- Version mismatch between tag and files
- Skipping version bump
- Non-sequential version numbers

## Verification

```bash
# Verify tag matches version file
./scripts/version-manager.sh latest
cat version.properties  # Should match

# Verify no uncommitted version changes
git status version.properties
```

## References

- `references/semver.md` - Semantic versioning guide
- `references/ci-integration.md` - CI/CD version workflows
