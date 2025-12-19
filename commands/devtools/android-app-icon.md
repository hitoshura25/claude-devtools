---
description: Generate Android adaptive icons from Iconify's 200k+ open source icons
---

# Android App Icon

Generates Android adaptive icons using VectorDrawables. Searches Iconify's library of 200,000+ open source icons.

## How It Works

This skill uses **executable scripts** for reliable, deterministic icon generation:

1. **Search:** `search-icons.sh <term>` - Find icons matching your app
2. **Generate:** `generate-app-icons.sh <icon-id>` - Create all icon assets

The scripts handle SVG → Android VectorDrawable conversion automatically.

## Requirements

- `curl`, `python3` - For Iconify API
- `rsvg-convert` - For Play Store PNG generation
  - macOS: `brew install librsvg`
  - Ubuntu: `sudo apt install librsvg2-bin`

## Usage

```bash
# Step 1: Search for icons
~/claude-devtools/skills/android-app-icon/scripts/search-icons.sh "health"

# Step 2: Generate icons (from project root)
~/claude-devtools/skills/android-app-icon/scripts/generate-app-icons.sh arcticons:health-sync
```

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

- [ ] Checked for legacy icon assets and asked user about removal (if found)
- [ ] User confirmed search term
- [ ] User selected icon from results
- [ ] All 5 output files generated
- [ ] `./gradlew assembleDebug` succeeds

## Skill Reference

`~/claude-devtools/skills/android-app-icon/SKILL.md`
