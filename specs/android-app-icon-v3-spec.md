# Android App Icon Skill v3 - Simplified Implementation Spec

## Overview

Complete rewrite of the android-app-icon skill focused on a single, clean approach:
- **VectorDrawable adaptive icons only** (no WebP/PNG mipmaps)
- **rsvg-convert for Play Store icon** (not ImageMagick)
- **Cleanup of legacy assets** with user confirmation
- **POSIX-compliant shell syntax** (works in bash and zsh)
- **Mandatory user confirmations** at key decision points

This spec supersedes `android-app-icon-v2-spec.md` and `android-app-icon-imagemagick-fix-spec.md`.

---

## Critical: User Confirmation Requirements

The skill has multiple points where the agent **MUST** stop and wait for user input. These are not optional.

### Confirmation Gates

| Step | Gate | Agent MUST Wait For |
|------|------|---------------------|
| Step 1 | Legacy asset cleanup | User choice: remove or keep |
| Step 2 | Search term | User confirmation or custom term |
| Step 3 | Icon selection | User selects icon number |
| Step 5 | Background color | User confirms or provides color |

**IMPORTANT FOR SKILL IMPLEMENTATION:**

Each confirmation point should be marked with:

```markdown
---
⏸️ **STOP: User input required**

[Present options to user]

**Do not proceed until user responds.**
---
```

This formatting makes it visually distinct and harder for the agent to skip.

---

## Critical: POSIX Shell Compatibility

All shell commands must work in both bash and zsh (macOS default). 

### Syntax Rules

| Bash-ism (AVOID) | POSIX-compliant (USE) |
|------------------|----------------------|
| `&> /dev/null` | `> /dev/null 2>&1` |
| `[[ ... ]]` | `[ ... ]` (for simple tests) |
| `$'string'` | `"string"` |
| `echo -n` | `printf` |
| Arrays `arr+=()` | Avoid or use separate commands |

### Checking Command Existence

```sh
# WRONG (bash-specific)
if ! command -v curl &> /dev/null; then

# CORRECT (POSIX)
if ! command -v curl > /dev/null 2>&1; then
```

### Printing Without Newline

```sh
# WRONG (may not work in all shells)
echo -n "Checking: "

# CORRECT (POSIX)
printf "Checking: "
```

### Testing Files

```sh
# OK for simple tests
if [ -f "$path" ]; then

# For complex conditions, use separate tests
```

---

## Key Decisions

### Why VectorDrawable Only?

For apps with `minSdk >= 26`:
- Android uses adaptive icons from `mipmap-anydpi-v26/`
- VectorDrawables render perfectly at any resolution
- WebP/PNG mipmaps are legacy fallbacks for pre-API 26 devices
- No raster generation needed except Play Store icon

### Why rsvg-convert Instead of ImageMagick?

- ImageMagick's SVG renderer is unreliable (fails to render paths)
- rsvg-convert (librsvg) is purpose-built for SVG rendering
- Single dependency, does one thing well

---

## Generated Files

```
app/src/main/res/
├── drawable/
│   ├── ic_launcher_foreground.xml    # VectorDrawable - the icon
│   └── ic_launcher_background.xml    # VectorDrawable - solid color
├── mipmap-anydpi-v26/
│   ├── ic_launcher.xml               # Adaptive icon definition
│   └── ic_launcher_round.xml         # Round adaptive icon definition
└── values/
    └── colors.xml                    # (update) Add icon colors if needed

fastlane/metadata/android/en-US/images/
└── icon.png                          # 512x512 PNG for Play Store
```

### Files NOT Generated (Legacy)

The skill should NOT create these for minSdk 26+ projects:
- `mipmap-mdpi/ic_launcher.webp`
- `mipmap-hdpi/ic_launcher.webp`
- `mipmap-xhdpi/ic_launcher.webp`
- `mipmap-xxhdpi/ic_launcher.webp`
- `mipmap-xxxhdpi/ic_launcher.webp`
- Any `ic_launcher_round.webp` files

---

## Prerequisites & Dependencies

### Required Tools

| Tool | Purpose | Check Command |
|------|---------|---------------|
| `curl` | Download icons from Iconify API | `command -v curl` |
| `rsvg-convert` | Render SVG to PNG (Play Store icon) | `command -v rsvg-convert` |

### Installing rsvg-convert

**macOS:**
```sh
brew install librsvg
```

**Ubuntu/Debian:**
```sh
sudo apt install librsvg2-bin
```

**Verify installation:**
```sh
rsvg-convert --version
```

---

## Implementation

### Step 0: Check Dependencies

```markdown
### Step 0: Verify Dependencies

**Check required tools (POSIX-compliant):**

```sh
printf "=== Checking Dependencies ===\n"

# Required: curl
printf "curl: "
if command -v curl > /dev/null 2>&1; then
    printf "✓\n"
else
    printf "✗ MISSING\n"
    printf "curl is required. Please install it first.\n"
    exit 1
fi

# Required: rsvg-convert
printf "rsvg-convert: "
if command -v rsvg-convert > /dev/null 2>&1; then
    printf "✓\n"
else
    printf "✗ MISSING\n"
    printf "\n"
    printf "rsvg-convert is required for Play Store icon generation.\n"
    printf "\n"
    printf "Install with:\n"
    printf "  macOS:  brew install librsvg\n"
    printf "  Ubuntu: sudo apt install librsvg2-bin\n"
    printf "\n"
    exit 1
fi

printf "\n=== Dependencies OK ===\n"
```

**Agent behavior when rsvg-convert is missing:**

---
⏸️ **STOP: User input required**

> "rsvg-convert is required to generate the Play Store icon (512x512 PNG). It's part of librsvg, a reliable SVG rendering library.
> 
> Would you like me to install librsvg?
> 
> **macOS:** `brew install librsvg`
> **Ubuntu:** `sudo apt install librsvg2-bin`
> 
> (y/n)"

**Do not proceed until user responds.**
---
```

### Step 1: Check for Existing Assets & Confirm Cleanup

```markdown
### Step 1: Check Existing Icon Assets

**Scan for existing icon files (POSIX-compliant):**

```sh
printf "=== Checking Existing Icon Assets ===\n"

# Check for legacy WebP/PNG mipmaps
FOUND_LEGACY=0

for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    for file in ic_launcher.webp ic_launcher.png ic_launcher_round.webp ic_launcher_round.png; do
        path="app/src/main/res/mipmap-${density}/${file}"
        if [ -f "$path" ]; then
            printf "  Found: %s\n" "$path"
            FOUND_LEGACY=1
        fi
    done
done

if [ "$FOUND_LEGACY" -eq 1 ]; then
    printf "\nThese are legacy raster files not needed for minSdk 26+.\n"
fi
```

---
⏸️ **STOP: User input required**

> "I found existing icon assets in your project (listed above).
> 
> Since your app targets minSdk 26+, Android uses VectorDrawable adaptive icons instead of these raster files. The legacy files will be ignored.
> 
> **Options:**
> 1. **Remove legacy files** - Clean project, only VectorDrawable icons
> 2. **Keep legacy files** - No changes to existing files
> 
> Which would you prefer? (1/2)"

**Do not proceed until user responds.**
---

**If user chooses to remove:**
```sh
# Remove legacy assets (agent executes after user confirms)
find app/src/main/res/mipmap-mdpi app/src/main/res/mipmap-hdpi \
     app/src/main/res/mipmap-xhdpi app/src/main/res/mipmap-xxhdpi \
     app/src/main/res/mipmap-xxxhdpi \
     -name "ic_launcher*.webp" -o -name "ic_launcher*.png" 2>/dev/null | \
while read -r file; do
    rm -v "$file"
done
printf "✓ Removed legacy icon assets\n"
```
```

### Step 2: Auto-Detect Search Term

```markdown
### Step 2: Detect Icon Search Term

**Analyze project for icon suggestions (POSIX-compliant):**

```sh
# Extract from package name
PACKAGE_NAME=""
if [ -f "app/build.gradle.kts" ]; then
    PACKAGE_NAME=$(grep 'namespace' app/build.gradle.kts 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
    if [ -z "$PACKAGE_NAME" ]; then
        PACKAGE_NAME=$(grep 'applicationId' app/build.gradle.kts | sed 's/.*"\(.*\)".*/\1/')
    fi
fi

# Extract meaningful words from package name
# e.g., "com.example.healthsyncapp" → "health"
if [ -n "$PACKAGE_NAME" ]; then
    LAST_SEGMENT=$(printf "%s" "$PACKAGE_NAME" | sed 's/.*\.\([^.]*\)$/\1/')
    # Add spaces before capitals, remove common suffixes
    KEYWORDS=$(printf "%s" "$LAST_SEGMENT" | \
               sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g' | \
               sed 's/[Aa]pp$//' | \
               sed 's/[Ss]ync$//' | \
               tr '[:upper:]' '[:lower:]')
fi

# Extract app name from strings.xml
APP_NAME=""
if [ -f "app/src/main/res/values/strings.xml" ]; then
    APP_NAME=$(grep 'name="app_name"' app/src/main/res/values/strings.xml 2>/dev/null | \
               sed 's/.*>\([^<]*\)<.*/\1/')
fi

printf "Package: %s\n" "$PACKAGE_NAME"
printf "Detected keywords: %s\n" "$KEYWORDS"
printf "App name: %s\n" "$APP_NAME"
```

---
⏸️ **STOP: User input required**

> "Based on your project, I detected:
> - Package: `{PACKAGE_NAME}`
> - Keywords: `{KEYWORDS}`
> - App name: `{APP_NAME}`
> 
> **Suggested search term:** `{KEYWORDS}`
> 
> Would you like to:
> 1. Use `{KEYWORDS}`
> 2. Enter a different search term
> 
> Please respond with 1, 2, or type your custom search term:"

**Do not proceed until user responds.**
---
```

### Step 3: Search Iconify

```markdown
### Step 3: Search Iconify for Icons

**Only execute AFTER user confirms search term in Step 2.**

```sh
SEARCH_TERM="${1:-health}"

# Search Iconify API
printf "Searching Iconify for '%s'...\n" "$SEARCH_TERM"
RESULTS=$(curl -s "https://api.iconify.design/search?query=${SEARCH_TERM}&limit=10")

# Parse and display results
printf "\nFound icons:\n"
printf "%s" "$RESULTS" | grep -o '"icons":\[[^]]*\]' | \
    sed 's/"icons":\[//;s/\]//;s/"//g' | \
    tr ',' '\n' | \
    nl
```

---
⏸️ **STOP: User input required**

> "Found icons matching '{SEARCH_TERM}':
> 
> 1. `mdi:heart-pulse`
> 2. `mdi:hospital-building`
> 3. `healthicons:health-worker`
> ...
> 
> **Preview:** https://icon-sets.iconify.design/mdi/heart-pulse/
> 
> Enter a number to select, or type a different search term:"

**Do not proceed until user responds.**
---
```

### Step 4: Download SVG from Iconify

```markdown
### Step 4: Download Selected Icon

**Only execute AFTER user selects icon in Step 3.**

```sh
ICON_ID="${1:-mdi:heart-pulse}"
ICON_COLOR="${2:-white}"

# Parse prefix and name
PREFIX=$(printf "%s" "$ICON_ID" | cut -d: -f1)
NAME=$(printf "%s" "$ICON_ID" | cut -d: -f2)

# Download SVG with color applied
printf "Downloading %s...\n" "$ICON_ID"
curl -s "https://api.iconify.design/${PREFIX}/${NAME}.svg?color=${ICON_COLOR}" \
     -o /tmp/icon_foreground.svg

# Verify download
if [ ! -s /tmp/icon_foreground.svg ]; then
    printf "Error: Failed to download icon\n"
    exit 1
fi

printf "✓ Downloaded %s\n" "$ICON_ID"
```
```

### Step 5: Convert SVG to Android VectorDrawable

```markdown
### Step 5: Create VectorDrawable from SVG

The agent parses the SVG and generates Android VectorDrawable XML.

**Key conversion rules:**
- SVG `viewBox` → Android `viewportWidth`/`viewportHeight`
- SVG `<path d="...">` → Android `<path android:pathData="...">`
- SVG `fill` → Android `android:fillColor`
- Wrap in `<group>` to center in 108dp adaptive icon safe zone

**Generated file: `app/src/main/res/drawable/ic_launcher_foreground.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    
    <!-- Center icon in 66dp safe zone (108 - 66 = 42, 42/2 = 21dp offset) -->
    <!-- Scale factor: 66/24 = 2.75 for 24x24 viewBox icons -->
    <group
        android:translateX="21"
        android:translateY="21"
        android:scaleX="2.75"
        android:scaleY="2.75">
        
        <!-- Path data from SVG -->
        <path
            android:fillColor="#FFFFFF"
            android:pathData="[PATH_DATA_FROM_SVG]"/>
    </group>
</vector>
```

---
⏸️ **STOP: User input required**

> "What background color would you like?
> 
> Detected from your project's `colors.xml`:
> - `colorPrimary`: #6200EE
> 
> Enter a hex color (e.g., #6200EE), or press Enter to use the detected color:"

**Do not proceed until user responds.**
---

**Generated file: `app/src/main/res/drawable/ic_launcher_background.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="[USER_SELECTED_COLOR]"
        android:pathData="M0,0h108v108H0z"/>
</vector>
```
```

### Step 6: Create Adaptive Icon XMLs

```markdown
### Step 6: Create Adaptive Icon Definitions

**Create directories and files (POSIX-compliant):**

```sh
mkdir -p app/src/main/res/mipmap-anydpi-v26

# Create ic_launcher.xml
cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF
printf "✓ Created ic_launcher.xml\n"

# Create ic_launcher_round.xml
cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF
printf "✓ Created ic_launcher_round.xml\n"
```
```

### Step 7: Generate Play Store Icon (512x512 PNG)

```markdown
### Step 7: Generate Play Store Icon

Use rsvg-convert to render a composite icon for the Play Store.

```sh
BACKGROUND_COLOR="${1:-#6200EE}"

# Read the downloaded SVG
ICON_SVG=$(cat /tmp/icon_foreground.svg)

# Extract path data from icon SVG
PATH_DATA=$(printf "%s" "$ICON_SVG" | grep -o 'd="[^"]*"' | head -1 | sed 's/d="//;s/"//')

# Create composite SVG (background + centered icon)
cat > /tmp/playstore_icon.svg << SVGEOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" fill="${BACKGROUND_COLOR}"/>
  <g transform="translate(102.4, 102.4) scale(12.8)">
    <path fill="white" d="${PATH_DATA}"/>
  </g>
</svg>
SVGEOF

# Render to PNG
mkdir -p fastlane/metadata/android/en-US/images

rsvg-convert -w 512 -h 512 /tmp/playstore_icon.svg \
             -o fastlane/metadata/android/en-US/images/icon.png

# Verify output
printf "Play Store icon: "
if [ -f "fastlane/metadata/android/en-US/images/icon.png" ]; then
    file fastlane/metadata/android/en-US/images/icon.png | grep -q "512 x 512" && \
        printf "✓ 512x512 PNG\n" || printf "✗ Wrong size\n"
else
    printf "✗ MISSING\n"
fi
```
```

### Step 8: Verify AndroidManifest

```markdown
### Step 8: Verify AndroidManifest Configuration

```sh
printf "=== AndroidManifest Check ===\n"

printf "android:icon: "
if grep -q 'android:icon="@mipmap/ic_launcher"' app/src/main/AndroidManifest.xml; then
    printf "✓\n"
else
    printf "⚠ MISSING - needs to be added\n"
fi

printf "android:roundIcon: "
if grep -q 'android:roundIcon="@mipmap/ic_launcher_round"' app/src/main/AndroidManifest.xml; then
    printf "✓\n"
else
    printf "⚠ MISSING - needs to be added\n"
fi
```
```

### Step 9: Final Verification

```markdown
### Step 9: Verify Generated Assets

```sh
printf "=== Final Verification ===\n"

# VectorDrawables
printf "ic_launcher_foreground.xml: "
[ -f "app/src/main/res/drawable/ic_launcher_foreground.xml" ] && printf "✓\n" || printf "✗ MISSING\n"

printf "ic_launcher_background.xml: "
[ -f "app/src/main/res/drawable/ic_launcher_background.xml" ] && printf "✓\n" || printf "✗ MISSING\n"

# Adaptive icon XMLs
printf "ic_launcher.xml: "
[ -f "app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" ] && printf "✓\n" || printf "✗ MISSING\n"

printf "ic_launcher_round.xml: "
[ -f "app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml" ] && printf "✓\n" || printf "✗ MISSING\n"

# Play Store icon
printf "Play Store icon: "
[ -f "fastlane/metadata/android/en-US/images/icon.png" ] && printf "✓\n" || printf "✗ MISSING\n"

# Build test
printf "\nBuilding to verify...\n"
./gradlew assembleDebug 2>&1 | tail -5
```
```

---

## Command File Update

**`commands/devtools/android-app-icon.md`:**

```markdown
---
description: Generate Android adaptive icons from Iconify's 200k+ open source icons
---

# Android App Icon

Generates Android adaptive icons using VectorDrawables. Searches Iconify's library of 200,000+ open source icons.

## What This Does

1. Checks for and optionally removes legacy raster icon files
2. Auto-detects a search term from your project
3. Searches Iconify for matching icons (with your confirmation)
4. Generates VectorDrawable adaptive icons
5. Creates 512x512 PNG for Play Store

## Requirements

- `curl` - For Iconify API
- `rsvg-convert` - For Play Store icon generation
  - macOS: `brew install librsvg`
  - Ubuntu: `sudo apt install librsvg2-bin`

## Generated Files

```
drawable/
├── ic_launcher_foreground.xml   # Icon VectorDrawable
└── ic_launcher_background.xml   # Background VectorDrawable

mipmap-anydpi-v26/
├── ic_launcher.xml              # Adaptive icon
└── ic_launcher_round.xml        # Round adaptive icon

fastlane/.../images/
└── icon.png                     # 512x512 Play Store icon
```

## Completion Criteria

- [ ] VectorDrawable foreground/background in `drawable/`
- [ ] `ic_launcher.xml` in `mipmap-anydpi-v26/`
- [ ] `ic_launcher_round.xml` in `mipmap-anydpi-v26/`
- [ ] Play Store icon (512x512 PNG)
- [ ] `./gradlew assembleDebug` builds successfully

## Skill Reference

`~/claude-devtools/skills/android-app-icon/SKILL.md`
```

---

## Files to Modify

| File | Action |
|------|--------|
| `skills/android-app-icon/SKILL.md` | **Replace entirely** with this approach |
| `commands/devtools/android-app-icon.md` | **Replace entirely** |

## Specs to Archive/Supersede

| Spec | Status |
|------|--------|
| `android-app-icon-v2-spec.md` | Superseded by this spec |
| `android-app-icon-imagemagick-fix-spec.md` | Superseded by this spec |

---

## Summary of Changes

| Aspect | Previous Specs | This Spec (v3) |
|--------|----------------|----------------|
| Shell syntax | Bash-specific | **POSIX-compliant** (bash + zsh) |
| User confirmations | Implicit | **Explicit gates with STOP markers** |
| Raster generation | WebP for all densities | **None** (VectorDrawable only) |
| Image tool | ImageMagick | **rsvg-convert** |
| Fallback approach | Pillow/Python | **None** (single tool) |
| Legacy asset handling | Not addressed | **Asks user to confirm removal** |
