---
name: android-app-icon
description: Generate Android adaptive icons from Iconify's 200k+ open source icons
category: android
version: 4.0.0
inputs:
  - search_term: Icon search term (for search step)
  - icon_id: Iconify icon ID (for generation step)
outputs:
  - app/src/main/res/drawable/ic_launcher_foreground.xml
  - app/src/main/res/drawable/ic_launcher_background.xml
  - app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  - app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml
  - fastlane/metadata/android/en-US/images/icon.png
verify: "./gradlew assembleDebug"
---

# Android App Icon

Generates Android adaptive icons using VectorDrawables from Iconify's 200,000+ open source icons.

## Prerequisites

- Android project with `minSdk >= 26`
- `curl`, `python3`, `rsvg-convert`

### Installing rsvg-convert

**macOS:**
```bash
brew install librsvg
```

**Ubuntu/Debian:**
```bash
sudo apt install librsvg2-bin
```

## How This Skill Works

This skill uses **executable scripts** located in the skill directory. The agent's role is to:
1. Check for and ask about legacy icon cleanup
2. Get user input (search term, icon selection)
3. Run the appropriate script with parameters
4. Verify output

The scripts handle all complexity including SVG → Android VectorDrawable conversion.

---

## Step 1: Check for Legacy Icon Assets

Before searching for icons, check if the project has legacy raster icons:

```bash
# Check for legacy WebP/PNG mipmaps
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    ls app/src/main/res/mipmap-${density}/ic_launcher*.webp \
       app/src/main/res/mipmap-${density}/ic_launcher*.png 2>/dev/null
done
```

---
⏸️ **STOP: If legacy icons exist, ask user about removal**

> "I found existing raster icon files (WebP/PNG) in your project. Since your app targets minSdk 26+, Android uses VectorDrawable adaptive icons from `mipmap-anydpi-v26/` instead. These legacy files are unnecessary.
>
> **Would you like me to remove them?** (yes/no)"

**If user says yes:**
```bash
find app/src/main/res/mipmap-mdpi app/src/main/res/mipmap-hdpi \
     app/src/main/res/mipmap-xhdpi app/src/main/res/mipmap-xxhdpi \
     app/src/main/res/mipmap-xxxhdpi \
     -name "ic_launcher*.webp" -o -name "ic_launcher*.png" 2>/dev/null | xargs rm -v
```

**If no legacy icons found:** Proceed to next step.

---

## Step 2: Search for Icons

Run the search script with the user's search term:

```bash
~/claude-devtools/skills/android-app-icon/scripts/search-icons.sh "<search-term>"
```

**Example:**
```bash
~/claude-devtools/skills/android-app-icon/scripts/search-icons.sh "health fitness"
```

---
⏸️ **STOP: Present results and wait for user to select an icon**

Show the numbered results and ask user to pick one or provide a different search term.

---

## Step 3: Generate Icons

Once user selects an icon, run the generation script:

```bash
cd /path/to/android/project
~/claude-devtools/skills/android-app-icon/scripts/generate-app-icons.sh "<icon-id>"
```

**Example:**
```bash
~/claude-devtools/skills/android-app-icon/scripts/generate-app-icons.sh arcticons:health-sync
```

The script automatically:
- Detects background color from `colors.xml` (colorPrimary)
- Scales icon to fit in adaptive icon safe zone
- Converts all SVG elements to Android-compatible paths
- Generates Play Store icon (512x512 PNG)

### Optional Overrides

If user wants different settings:

```bash
ICON_BACKGROUND="#2196F3" ICON_SCALE="1.2" \
  ~/claude-devtools/skills/android-app-icon/scripts/generate-app-icons.sh mdi:heart-pulse
```

| Variable | Default | Description |
|----------|---------|-------------|
| `ICON_BACKGROUND` | Auto-detect from colorPrimary | Background hex color |
| `ICON_SCALE` | 1.15 | Scale factor (1.0 = fit exactly in safe zone) |
| `ICON_COLOR` | white | Foreground color |

---

## Generated Files

```
app/src/main/res/
├── drawable/
│   ├── ic_launcher_foreground.xml    # VectorDrawable icon
│   └── ic_launcher_background.xml    # VectorDrawable background
├── mipmap-anydpi-v26/
│   ├── ic_launcher.xml               # Adaptive icon definition
│   └── ic_launcher_round.xml         # Round adaptive icon

fastlane/metadata/android/en-US/images/
└── icon.png                          # 512x512 Play Store icon
```

---

## SVG → Android VectorDrawable Conversion

The scripts automatically convert SVG elements that Android doesn't support:

| SVG Element | Conversion |
|-------------|------------|
| `<circle>` | Arc path (`A` commands) |
| `<ellipse>` | Arc path |
| `<rect>` | Rectangular path (`M`, `h`, `v`) |
| `<line>` | Line path (`M`, `L`) |
| `<polygon>` | Closed path with `Z` |
| `<polyline>` | Open path |
| `<path>` | Attribute renaming only |

This is handled automatically - no agent intervention needed.

---

## Confirmation Gates

| Step | Agent MUST Wait For |
|------|---------------------|
| Step 1 - Legacy icons | If legacy icons found, user confirms removal (yes/no) |
| Step 2 - After search | User selects icon number or provides new search term |
| Step 3 - Before generate | User confirms icon selection |

---

## Step 4: Verify

After generation, verify the build:

```bash
./gradlew assembleDebug
```

Check that all files exist:
- `app/src/main/res/drawable/ic_launcher_foreground.xml`
- `app/src/main/res/drawable/ic_launcher_background.xml`
- `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`
- `fastlane/metadata/android/en-US/images/icon.png`

---

## Completion Criteria

- [ ] Checked for legacy icon assets and asked user about removal (if found)
- [ ] `search-icons.sh` run with user-confirmed search term
- [ ] User selected icon from results
- [ ] `generate-app-icons.sh` run with selected icon ID
- [ ] All 5 output files exist
- [ ] `./gradlew assembleDebug` succeeds
- [ ] Icon visible in Android Studio Resource Manager

---

## Why Scripts?

Previous versions had the agent interpret inline instructions, leading to inconsistent results (40-60% reliability). Scripts provide:

1. **Deterministic execution** - Same input → same output
2. **Tested conversion logic** - SVG elements converted correctly
3. **Single source of truth** - Fix once, works everywhere
4. **Minimal agent decisions** - Just pass parameters

---

## Troubleshooting

### Icon appears cut off
The icon's SVG may have elements outside the viewBox. Try reducing scale:
```bash
ICON_SCALE=1.0 ~/claude-devtools/skills/android-app-icon/scripts/generate-app-icons.sh <icon>
```

### Missing head/parts of icon
SVG may contain `<circle>`, `<rect>`, etc. that weren't converted. Check the generated foreground.xml for `<!-- Skipped unsupported element -->` comments.

### rsvg-convert not found
```bash
# macOS
brew install librsvg

# Ubuntu
sudo apt install librsvg2-bin
```

### Icon not found
Verify the icon ID at https://icon-sets.iconify.design/
