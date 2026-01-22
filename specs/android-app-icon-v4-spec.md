# Android App Icon Skill v4 - Script-Based Implementation Spec

## Overview

This spec evolves the android-app-icon skill to use **executable scripts** as the source of truth for icon generation. Instead of the agent interpreting inline instructions differently each time, the agent runs well-tested scripts that handle all the complexity.

**Key changes from v3:**
- Scripts live in the skill directory and are executed directly
- Agent's role is orchestration (get user input, run scripts with params)
- SVG → Android VectorDrawable conversion logic is encapsulated in scripts
- Minimal required parameters (search term, icon ID only)
- Everything else auto-detected from project context

---

## Architecture

```
skills/android-app-icon/
├── SKILL.md                    # Skill documentation
└── scripts/
    ├── search-icons.sh         # Search Iconify API
    ├── generate-app-icons.sh   # Generate all icon assets
    └── lib/
        └── svg-to-android.py   # SVG element conversion library
```

**Execution flow:**
1. Agent runs `search-icons.sh <term>` → presents results to user
2. User selects icon
3. Agent runs `generate-app-icons.sh <icon-id>` → generates all assets
4. Agent verifies output and builds project

---

## Critical: SVG to Android VectorDrawable Conversion

Android VectorDrawables **only support `<path>` elements**. The scripts must convert unsupported SVG elements:

| SVG Element | Conversion Required |
|-------------|---------------------|
| `<path>` | Attribute renaming only |
| `<circle>` | Convert to arc path |
| `<rect>` | Convert to path |
| `<ellipse>` | Convert to arc path |
| `<line>` | Convert to M/L path |
| `<polygon>` | Convert to path |
| `<polyline>` | Convert to path |

### Conversion Algorithms

**Circle to Path:**
```python
def circle_to_path(cx, cy, r):
    """Two 180° arcs to form a circle."""
    return f"M {cx},{cy - r} A {r},{r} 0 1,0 {cx},{cy + r} A {r},{r} 0 1,0 {cx},{cy - r}"
```

**Ellipse to Path:**
```python
def ellipse_to_path(cx, cy, rx, ry):
    """Two 180° arcs to form an ellipse."""
    return f"M {cx},{cy - ry} A {rx},{ry} 0 1,0 {cx},{cy + ry} A {rx},{ry} 0 1,0 {cx},{cy - ry}"
```

**Rect to Path:**
```python
def rect_to_path(x, y, width, height, rx=0, ry=0):
    """Rectangle to path, with optional rounded corners."""
    if rx == 0 and ry == 0:
        return f"M {x},{y} h {width} v {height} h -{width} Z"
    # Rounded corners require arc commands
    # ... (more complex)
```

**Line to Path:**
```python
def line_to_path(x1, y1, x2, y2):
    return f"M {x1},{y1} L {x2},{y2}"
```

**Polygon to Path:**
```python
def polygon_to_path(points):
    """Points string like '0,0 10,0 10,10' to path."""
    coords = points.strip().split()
    path = f"M {coords[0]}"
    for coord in coords[1:]:
        path += f" L {coord}"
    return path + " Z"
```

---

## Script Specifications

### search-icons.sh

**Location:** `skills/android-app-icon/scripts/search-icons.sh`

**Purpose:** Search Iconify's 200k+ icon library

**Required params:**
- `$1` - Search term (required)

**Optional params:**
- `$2` - Result limit (default: 10)

**Output:** Numbered list of icons with collection/license info

```bash
#!/bin/sh
# Search Iconify for icons
# Usage: search-icons.sh <search-term> [limit]

set -e

SEARCH_TERM="${1:?Usage: search-icons.sh <search-term> [limit]}"
LIMIT="${2:-10}"

# URL encode the search term
ENCODED_TERM=$(printf "%s" "$SEARCH_TERM" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))")

printf "=== Searching Iconify for: %s ===\n\n" "$SEARCH_TERM"

# Search and format results
curl -s "https://api.iconify.design/search?query=${ENCODED_TERM}&limit=${LIMIT}" | python3 << 'PYEOF'
import json, sys

data = json.load(sys.stdin)
icons = data.get('icons', [])
collections = data.get('collections', {})

if not icons:
    print("No icons found.")
    sys.exit(0)

print(f"Found {data.get('total', len(icons))} icons (showing {len(icons)}):\n")

for i, icon in enumerate(icons, 1):
    parts = icon.split(':')
    collection_id = parts[0]
    
    collection_info = collections.get(collection_id, {})
    collection_name = collection_info.get('name', collection_id)
    license_info = collection_info.get('license', {})
    license_name = license_info.get('title', 'Unknown')
    
    print(f"{i}. {icon}")
    print(f"   Collection: {collection_name}")
    print(f"   License: {license_name}")
    print(f"   Preview: https://icon-sets.iconify.design/{collection_id}/{parts[1]}/")
    print()

print("\nTo generate icons, use:")
print(f"  generate-app-icons.sh {icons[0]}")
PYEOF
```

---

### generate-app-icons.sh

**Location:** `skills/android-app-icon/scripts/generate-app-icons.sh`

**Purpose:** Generate all Android icon assets from an Iconify icon

**Required params:**
- `$1` - Icon ID (e.g., `arcticons:health-sync`)

**Auto-detected from project:**
- Background color (from `colors.xml` → `colorPrimary`)
- Icon scale (default: 1.15, fits 48x48 icons in 66dp safe zone)
- Output paths (standard Android project structure)

**Optional environment overrides:**
- `ICON_BACKGROUND` - Override background color
- `ICON_SCALE` - Override scale factor
- `ICON_COLOR` - Override foreground color (default: white)

```bash
#!/bin/sh
# Generate Android app icons from Iconify
# Usage: generate-app-icons.sh <icon-id>
#
# Environment overrides:
#   ICON_BACKGROUND - Background color (default: auto-detect from colors.xml)
#   ICON_SCALE      - Scale factor (default: 1.15)
#   ICON_COLOR      - Foreground color (default: white)

set -e

ICON_ID="${1:?Usage: generate-app-icons.sh <icon-id> (e.g., arcticons:health-sync)}"

# Parse icon ID
ICON_COLLECTION=$(printf "%s" "$ICON_ID" | cut -d: -f1)
ICON_NAME=$(printf "%s" "$ICON_ID" | cut -d: -f2)

# Auto-detect or use overrides
ICON_COLOR="${ICON_COLOR:-white}"
ICON_SCALE="${ICON_SCALE:-1.15}"

# Auto-detect background color from project
if [ -z "$ICON_BACKGROUND" ]; then
    if [ -f "app/src/main/res/values/colors.xml" ]; then
        ICON_BACKGROUND=$(grep -E 'name="colorPrimary"' app/src/main/res/values/colors.xml 2>/dev/null | \
                          sed 's/.*>\(#[^<]*\)<.*/\1/' | head -1)
    fi
    ICON_BACKGROUND="${ICON_BACKGROUND:-#4CAF50}"
fi

# Paths
DRAWABLE_DIR="app/src/main/res/drawable"
MIPMAP_DIR="app/src/main/res/mipmap-anydpi-v26"
PLAYSTORE_DIR="fastlane/metadata/android/en-US/images"
TMP_DIR="/tmp/android-icons-$$"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Cleanup on exit
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

printf "=== Android App Icon Generator ===\n"
printf "Icon: %s\n" "$ICON_ID"
printf "Background: %s\n" "$ICON_BACKGROUND"
printf "Scale: %s\n" "$ICON_SCALE"
printf "\n"

# Check dependencies
printf "Checking dependencies...\n"
for cmd in curl python3 rsvg-convert; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        printf "Error: %s not found\n" "$cmd"
        if [ "$cmd" = "rsvg-convert" ]; then
            printf "Install with:\n"
            printf "  macOS:  brew install librsvg\n"
            printf "  Ubuntu: sudo apt install librsvg2-bin\n"
        fi
        exit 1
    fi
done
printf "✓ Dependencies OK\n\n"

# Step 1: Fetch icon from Iconify
printf "Step 1: Fetching icon from Iconify API...\n"
curl -s "https://api.iconify.design/${ICON_COLLECTION}.json?icons=${ICON_NAME}" > "$TMP_DIR/icon-data.json"

# Extract SVG body and metadata
ICON_DATA=$(python3 << PYEOF
import json, sys

with open('$TMP_DIR/icon-data.json') as f:
    data = json.load(f)

icon = data.get('icons', {}).get('$ICON_NAME', {})
if not icon:
    print("ERROR:Icon not found", file=sys.stderr)
    sys.exit(1)

body = icon.get('body', '')
width = icon.get('width', data.get('width', 24))
height = icon.get('height', data.get('height', 24))

print(f"WIDTH:{width}")
print(f"HEIGHT:{height}")
print(f"BODY:{body}")
PYEOF
)

if printf "%s" "$ICON_DATA" | grep -q "ERROR:"; then
    printf "Error: Failed to fetch icon\n"
    exit 1
fi

ICON_WIDTH=$(printf "%s" "$ICON_DATA" | grep "^WIDTH:" | cut -d: -f2)
ICON_HEIGHT=$(printf "%s" "$ICON_DATA" | grep "^HEIGHT:" | cut -d: -f2)
ICON_BODY=$(printf "%s" "$ICON_DATA" | grep "^BODY:" | cut -d: -f2-)

printf "✓ Fetched icon (viewBox: %sx%s)\n\n" "$ICON_WIDTH" "$ICON_HEIGHT"

# Step 2: Generate VectorDrawable foreground
printf "Step 2: Generating ic_launcher_foreground.xml...\n"
mkdir -p "$DRAWABLE_DIR"

# Calculate centering for adaptive icon (108dp canvas, 66dp safe zone)
# For a WxH viewBox icon scaled to fit in 66dp:
# scale = 66 / max(W, H)
# translate = (108 - W*scale) / 2, (108 - H*scale) / 2

python3 << PYEOF > "$DRAWABLE_DIR/ic_launcher_foreground.xml"
import re
import sys

icon_body = '''$ICON_BODY'''
icon_width = float($ICON_WIDTH)
icon_height = float($ICON_HEIGHT)
scale = float($ICON_SCALE)

# Calculate scale to fit in 66dp safe zone
base_scale = 66.0 / max(icon_width, icon_height)
final_scale = base_scale * scale

# Calculate translation to center
translate_x = (108 - icon_width * final_scale) / 2
translate_y = (108 - icon_height * final_scale) / 2

def circle_to_path(cx, cy, r):
    """Convert SVG circle to path with two arcs."""
    cx, cy, r = float(cx), float(cy), float(r)
    return f"M {cx},{cy - r} A {r},{r} 0 1,0 {cx},{cy + r} A {r},{r} 0 1,0 {cx},{cy - r}"

def ellipse_to_path(cx, cy, rx, ry):
    """Convert SVG ellipse to path with two arcs."""
    cx, cy, rx, ry = float(cx), float(cy), float(rx), float(ry)
    return f"M {cx},{cy - ry} A {rx},{ry} 0 1,0 {cx},{cy + ry} A {rx},{ry} 0 1,0 {cx},{cy - ry}"

def rect_to_path(x, y, w, h):
    """Convert SVG rect to path."""
    x, y, w, h = float(x), float(y), float(w), float(h)
    return f"M {x},{y} h {w} v {h} h -{w} Z"

def line_to_path(x1, y1, x2, y2):
    """Convert SVG line to path."""
    return f"M {x1},{y1} L {x2},{y2}"

def polygon_to_path(points):
    """Convert SVG polygon points to path."""
    coords = points.strip().replace(',', ' ').split()
    pairs = [f"{coords[i]},{coords[i+1]}" for i in range(0, len(coords), 2)]
    return f"M {pairs[0]} " + " ".join(f"L {p}" for p in pairs[1:]) + " Z"

def polyline_to_path(points):
    """Convert SVG polyline points to path."""
    coords = points.strip().replace(',', ' ').split()
    pairs = [f"{coords[i]},{coords[i+1]}" for i in range(0, len(coords), 2)]
    return f"M {pairs[0]} " + " ".join(f"L {p}" for p in pairs[1:])

def extract_attr(element, attr):
    """Extract attribute value from element string."""
    match = re.search(rf'{attr}="([^"]*)"', element)
    return match.group(1) if match else None

def has_stroke(element):
    """Check if element has stroke styling."""
    return 'stroke=' in element or 'stroke-width' in element

def convert_element(element):
    """Convert SVG element to Android VectorDrawable path."""
    
    # Determine fill vs stroke style
    is_stroked = has_stroke(element)
    fill_color = "#00000000" if is_stroked else "#FFFFFF"
    stroke_attrs = ""
    if is_stroked:
        stroke_attrs = '''
            android:strokeWidth="1"
            android:strokeColor="#FFFFFF"
            android:strokeLineCap="round"
            android:strokeLineJoin="round"'''
    
    # Circle
    match = re.match(r'<circle\s+([^>]+)/>', element)
    if match:
        attrs = match.group(1)
        cx = extract_attr(element, 'cx') or '0'
        cy = extract_attr(element, 'cy') or '0'
        r = extract_attr(element, 'r') or '0'
        path_data = circle_to_path(cx, cy, r)
        return f'''        <path
            android:pathData="{path_data}"
            android:fillColor="{fill_color}"{stroke_attrs}/>'''
    
    # Ellipse
    match = re.match(r'<ellipse\s+([^>]+)/>', element)
    if match:
        cx = extract_attr(element, 'cx') or '0'
        cy = extract_attr(element, 'cy') or '0'
        rx = extract_attr(element, 'rx') or '0'
        ry = extract_attr(element, 'ry') or '0'
        path_data = ellipse_to_path(cx, cy, rx, ry)
        return f'''        <path
            android:pathData="{path_data}"
            android:fillColor="{fill_color}"{stroke_attrs}/>'''
    
    # Rect
    match = re.match(r'<rect\s+([^>]+)/>', element)
    if match:
        x = extract_attr(element, 'x') or '0'
        y = extract_attr(element, 'y') or '0'
        w = extract_attr(element, 'width') or '0'
        h = extract_attr(element, 'height') or '0'
        path_data = rect_to_path(x, y, w, h)
        return f'''        <path
            android:pathData="{path_data}"
            android:fillColor="{fill_color}"{stroke_attrs}/>'''
    
    # Line
    match = re.match(r'<line\s+([^>]+)/>', element)
    if match:
        x1 = extract_attr(element, 'x1') or '0'
        y1 = extract_attr(element, 'y1') or '0'
        x2 = extract_attr(element, 'x2') or '0'
        y2 = extract_attr(element, 'y2') or '0'
        path_data = line_to_path(x1, y1, x2, y2)
        return f'''        <path
            android:pathData="{path_data}"
            android:fillColor="#00000000"
            android:strokeWidth="1"
            android:strokeColor="#FFFFFF"
            android:strokeLineCap="round"/>'''
    
    # Polygon
    match = re.match(r'<polygon\s+([^>]+)/>', element)
    if match:
        points = extract_attr(element, 'points') or ''
        path_data = polygon_to_path(points)
        return f'''        <path
            android:pathData="{path_data}"
            android:fillColor="{fill_color}"{stroke_attrs}/>'''
    
    # Polyline
    match = re.match(r'<polyline\s+([^>]+)/>', element)
    if match:
        points = extract_attr(element, 'points') or ''
        path_data = polyline_to_path(points)
        return f'''        <path
            android:pathData="{path_data}"
            android:fillColor="#00000000"
            android:strokeWidth="1"
            android:strokeColor="#FFFFFF"
            android:strokeLineCap="round"
            android:strokeLineJoin="round"/>'''
    
    # Path (just convert attributes)
    match = re.match(r'<path\s+([^>]+)/>', element)
    if match:
        path_data = extract_attr(element, 'd') or ''
        return f'''        <path
            android:pathData="{path_data}"
            android:fillColor="{fill_color}"{stroke_attrs}/>'''
    
    # Unknown element - skip with comment
    return f"        <!-- Skipped unsupported element -->"

# Find all SVG elements
elements = re.findall(r'<(?:path|circle|ellipse|rect|line|polygon|polyline)[^>]*/>', icon_body)
converted = [convert_element(el) for el in elements]

print(f'''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="{final_scale:.4f}"
        android:scaleY="{final_scale:.4f}"
        android:translateX="{translate_x:.4f}"
        android:translateY="{translate_y:.4f}">
        <!-- Icon: $ICON_ID -->
        <!-- Original viewBox: {icon_width}x{icon_height} -->
{chr(10).join(converted)}
    </group>
</vector>''')
PYEOF

printf "✓ Created ic_launcher_foreground.xml\n\n"

# Step 3: Generate VectorDrawable background
printf "Step 3: Generating ic_launcher_background.xml...\n"

cat > "$DRAWABLE_DIR/ic_launcher_background.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="$ICON_BACKGROUND"
        android:pathData="M0,0h108v108h-108z" />
</vector>
EOF

printf "✓ Created ic_launcher_background.xml\n\n"

# Step 4: Create adaptive icon XMLs
printf "Step 4: Creating adaptive icon definitions...\n"
mkdir -p "$MIPMAP_DIR"

cat > "$MIPMAP_DIR/ic_launcher.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
EOF

cat > "$MIPMAP_DIR/ic_launcher_round.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
EOF

printf "✓ Created ic_launcher.xml\n"
printf "✓ Created ic_launcher_round.xml\n\n"

# Step 5: Generate Play Store icon
printf "Step 5: Generating Play Store icon (512x512 PNG)...\n"
mkdir -p "$PLAYSTORE_DIR"

# Fetch SVG directly from Iconify with color applied
curl -s "https://api.iconify.design/${ICON_COLLECTION}/${ICON_NAME}.svg?color=${ICON_COLOR}" > "$TMP_DIR/icon.svg"

# Create composite SVG with background
cat > "$TMP_DIR/playstore.svg" << SVGEOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" fill="$ICON_BACKGROUND"/>
  <g transform="translate(128, 128) scale(${ICON_SCALE})">
    $(cat "$TMP_DIR/icon.svg" | sed 's/<svg[^>]*>//;s/<\/svg>//')
  </g>
</svg>
SVGEOF

# Render to PNG
rsvg-convert -w 512 -h 512 "$TMP_DIR/playstore.svg" -o "$PLAYSTORE_DIR/icon.png"

printf "✓ Created icon.png\n\n"

# Step 6: Verification
printf "=== Verification ===\n"

check_file() {
    if [ -f "$1" ]; then
        printf "✓ %s\n" "$1"
        return 0
    else
        printf "✗ %s (MISSING)\n" "$1"
        return 1
    fi
}

ERRORS=0
check_file "$DRAWABLE_DIR/ic_launcher_foreground.xml" || ERRORS=$((ERRORS + 1))
check_file "$DRAWABLE_DIR/ic_launcher_background.xml" || ERRORS=$((ERRORS + 1))
check_file "$MIPMAP_DIR/ic_launcher.xml" || ERRORS=$((ERRORS + 1))
check_file "$MIPMAP_DIR/ic_launcher_round.xml" || ERRORS=$((ERRORS + 1))
check_file "$PLAYSTORE_DIR/icon.png" || ERRORS=$((ERRORS + 1))

printf "\n"

if [ "$ERRORS" -gt 0 ]; then
    printf "⚠ %d file(s) missing\n" "$ERRORS"
    exit 1
fi

printf "=== Generation Complete ===\n"
printf "\nNext steps:\n"
printf "  1. Review icons in Android Studio Resource Manager\n"
printf "  2. Build: ./gradlew assembleDebug\n"
printf "  3. Optional: Remove legacy raster icons:\n"
printf "     find app/src/main/res/mipmap-* -name '*.webp' -delete\n"
```

---

## Skill SKILL.md Update

The updated skill documentation should reference the scripts:

```markdown
---
name: android-app-icon
description: Generate Android adaptive icons from Iconify's 200k+ open source icons
category: android
version: 4.0.0
inputs:
  - search_term: Icon search term (required for search)
  - icon_id: Iconify icon ID (required for generation)
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

Install rsvg-convert:
- macOS: `brew install librsvg`
- Ubuntu: `sudo apt install librsvg2-bin`

## Usage

This skill uses scripts located in the skill directory. The agent runs these scripts with user-provided parameters.

### Step 1: Search for Icons

```bash
~/claude-devtools/skills/android-app-icon/scripts/search-icons.sh "health fitness"
```

---
⏸️ **STOP: Present results and wait for user selection**
---

### Step 2: Generate Icons

```bash
~/claude-devtools/skills/android-app-icon/scripts/generate-app-icons.sh arcticons:health-sync
```

The script auto-detects:
- Background color from `colors.xml` (colorPrimary)
- Scale factor (default 1.15)
- Output paths (standard Android structure)

### Optional Overrides

```bash
ICON_BACKGROUND="#2196F3" ICON_SCALE="1.2" \
  ~/claude-devtools/skills/android-app-icon/scripts/generate-app-icons.sh mdi:heart-pulse
```

## What Gets Generated

```
app/src/main/res/
├── drawable/
│   ├── ic_launcher_foreground.xml    # VectorDrawable icon
│   └── ic_launcher_background.xml    # VectorDrawable background
├── mipmap-anydpi-v26/
│   ├── ic_launcher.xml               # Adaptive icon
│   └── ic_launcher_round.xml         # Round adaptive icon

fastlane/metadata/android/en-US/images/
└── icon.png                          # 512x512 Play Store icon
```

## SVG Conversion

The scripts handle SVG → Android VectorDrawable conversion automatically, including:
- `<circle>` → arc path
- `<ellipse>` → arc path  
- `<rect>` → rectangular path
- `<line>` → line path
- `<polygon>` → closed path
- `<polyline>` → open path

## Confirmation Gates

| Step | Agent MUST Wait For |
|------|---------------------|
| Search results | User selects icon number or provides new search term |
| Before generation | User confirms icon selection |

## Completion Criteria

- [ ] VectorDrawable files in `drawable/`
- [ ] Adaptive icon XMLs in `mipmap-anydpi-v26/`
- [ ] Play Store icon (512x512 PNG)
- [ ] `./gradlew assembleDebug` succeeds
```

---

## Files to Create/Modify

| Path | Action |
|------|--------|
| `skills/android-app-icon/SKILL.md` | Update to v4 |
| `skills/android-app-icon/scripts/search-icons.sh` | Create |
| `skills/android-app-icon/scripts/generate-app-icons.sh` | Create |
| `commands/devtools/android-app-icon.md` | Update description |

---

## Key Differences from v3

| Aspect | v3 | v4 |
|--------|----|----|
| Execution | Agent interprets inline instructions | Agent runs scripts |
| SVG conversion | Agent implements each time | Script handles all cases |
| Reliability | Varies by interpretation | Deterministic scripts |
| Parameters | Multiple confirmations | Minimal (search term, icon ID) |
| Auto-detection | Inline bash | Script handles internally |
| Maintainability | Update SKILL.md | Update scripts |

---

## Testing the Scripts

Before deploying, test scripts on health-sync-app:

```bash
# Test search
~/claude-devtools/skills/android-app-icon/scripts/search-icons.sh "health sync"

# Test generation
cd ~/health-sync-app
~/claude-devtools/skills/android-app-icon/scripts/generate-app-icons.sh arcticons:health-sync

# Verify
./gradlew assembleDebug
```
