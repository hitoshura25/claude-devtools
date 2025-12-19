# Android App Icon Scripts - Bug Fixes Spec

## Overview

This spec documents bug fixes for the android-app-icon skill scripts created in v4. These are targeted fixes, not a full rewrite.

---

## Fix 1: search-icons.sh Pipe Reliability Issue

### Problem

The current implementation pipes curl output directly to Python stdin via heredoc:

```bash
curl -s "..." | python3 << 'PYEOF'
import json, sys
data = json.load(sys.stdin)
# ...
PYEOF
```

**Issues:**
- If curl fails silently or returns malformed JSON, Python crashes with `JSONDecodeError`
- Pipe + heredoc combination can be unreliable in some shell environments
- No error handling for API failures

### Solution

Save curl response to temp file first, validate JSON, then process:

```bash
#!/bin/sh
# ... (keep existing header and variable setup)

# Create temp file for API response
RESPONSE_FILE=$(mktemp)
trap 'rm -f "$RESPONSE_FILE"' EXIT

# Fetch from API
printf "Fetching results...\n"
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" \
    "https://api.iconify.design/search?query=${ENCODED_TERM}&limit=${LIMIT}")

# Check HTTP status
if [ "$HTTP_CODE" != "200" ]; then
    printf "Error: API returned HTTP %s\n" "$HTTP_CODE"
    exit 1
fi

# Validate JSON before parsing
if ! python3 -c "import json; json.load(open('$RESPONSE_FILE'))" 2>/dev/null; then
    printf "Error: API returned invalid JSON\n"
    cat "$RESPONSE_FILE"  # Show response for debugging
    exit 1
fi

# Process valid response
python3 - "$RESPONSE_FILE" << 'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

icons = data.get('icons', [])
collections = data.get('collections', {})

if not icons:
    print("No icons found.")
    sys.exit(0)

# ... rest of formatting code unchanged ...
PYEOF
```

**Key changes:**
1. Use `mktemp` for temp file with cleanup trap
2. Capture HTTP status code with `-w "%{http_code}"`
3. Validate JSON before passing to Python
4. Pass file path as argument instead of stdin
5. Use `python3 -` to read script from stdin while accepting file argument

---

## Fix 2: Color Detection from themes.xml

### Problem

Current implementation looks for `colorPrimary` directly in `colors.xml`:

```bash
if [ -f "app/src/main/res/values/colors.xml" ]; then
    ICON_BACKGROUND=$(grep -E 'name="colorPrimary"' app/src/main/res/values/colors.xml 2>/dev/null | \
                      sed 's/.*>\(#[^<]*\)<.*/\1/' | head -1)
fi
```

**Issues:**
- `colorPrimary` is typically defined in `themes.xml`, not `colors.xml`
- `themes.xml` uses color references like `@color/purple_500`, not hex values
- Need to resolve the reference to get actual hex value

### Example from health-sync-app

**themes.xml:**
```xml
<item name="colorPrimary">@color/purple_500</item>
```

**colors.xml:**
```xml
<color name="purple_500">#FF6200EE</color>
```

### Solution

Two-step color resolution:

```bash
# Auto-detect background color from project
if [ -z "$ICON_BACKGROUND" ]; then
    ICON_BACKGROUND=""
    
    # Step 1: Check themes.xml for colorPrimary (most common location)
    if [ -f "app/src/main/res/values/themes.xml" ]; then
        COLOR_REF=$(grep -E 'name="colorPrimary"' app/src/main/res/values/themes.xml 2>/dev/null | \
                    sed 's/.*>\([^<]*\)<.*/\1/' | head -1)
        
        if [ -n "$COLOR_REF" ]; then
            # Check if it's a reference (@color/name) or direct hex value
            case "$COLOR_REF" in
                @color/*)
                    # Extract color name from reference
                    COLOR_NAME=$(printf "%s" "$COLOR_REF" | sed 's/@color\///')
                    
                    # Look up in colors.xml
                    if [ -f "app/src/main/res/values/colors.xml" ]; then
                        ICON_BACKGROUND=$(grep -E "name=\"${COLOR_NAME}\"" app/src/main/res/values/colors.xml 2>/dev/null | \
                                          sed 's/.*>\(#[^<]*\)<.*/\1/' | head -1)
                    fi
                    ;;
                \#*)
                    # Direct hex value
                    ICON_BACKGROUND="$COLOR_REF"
                    ;;
            esac
        fi
    fi
    
    # Step 2: Fallback - check colors.xml directly for colorPrimary
    if [ -z "$ICON_BACKGROUND" ] && [ -f "app/src/main/res/values/colors.xml" ]; then
        ICON_BACKGROUND=$(grep -E 'name="colorPrimary"' app/src/main/res/values/colors.xml 2>/dev/null | \
                          sed 's/.*>\(#[^<]*\)<.*/\1/' | head -1)
    fi
    
    # Step 3: Default fallback
    ICON_BACKGROUND="${ICON_BACKGROUND:-#4CAF50}"
fi

printf "Background color: %s\n" "$ICON_BACKGROUND"
```

**Logic flow:**
1. Check `themes.xml` for `colorPrimary`
2. If found and is a reference (`@color/name`), resolve from `colors.xml`
3. If found and is hex value, use directly
4. Fallback: check `colors.xml` directly for `colorPrimary`
5. Final fallback: use default `#4CAF50`

---

## Files to Modify

| File | Fix |
|------|-----|
| `skills/android-app-icon/scripts/search-icons.sh` | Fix 1: Pipe reliability |
| `skills/android-app-icon/scripts/generate-app-icons.sh` | Fix 2: Color detection |

---

## Testing

### Test Fix 1 (search-icons.sh)

```bash
# Test with valid search
~/claude-devtools/skills/android-app-icon/scripts/search-icons.sh "health"

# Test with empty results
~/claude-devtools/skills/android-app-icon/scripts/search-icons.sh "xyznonexistent12345"

# Test error handling (disconnect network or use invalid URL)
```

### Test Fix 2 (generate-app-icons.sh)

```bash
cd ~/health-sync-app

# Should detect #FF6200EE from themes.xml → @color/purple_500 → colors.xml
~/claude-devtools/skills/android-app-icon/scripts/generate-app-icons.sh arcticons:health-sync

# Verify output shows: "Background color: #FF6200EE"
```

---

## Implementation Notes

1. Both fixes use POSIX-compliant shell syntax (no bash-isms)
2. Temp file cleanup uses `trap` for reliability
3. Color resolution handles both `@color/` references and direct hex values
4. All `grep`/`sed` patterns are kept simple for portability
