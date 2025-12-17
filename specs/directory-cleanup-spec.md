# Directory Structure Cleanup Spec

**Purpose:** Resolve conflicts between old (r0adkll) and new (GPP) directory conventions
**Date:** 2025-12-15
**Status:** Ready for Implementation

---

## Problem Summary

The v4 migration to Gradle Play Publisher (GPP) introduced new directory conventions that conflict with older skills:

### Release Notes Location Conflict

| Convention | Location | Status |
|------------|----------|--------|
| **Old (r0adkll)** | `distribution/whatsnew/en-US/whatsnew` | ❌ Deprecated |
| **New (GPP)** | `src/main/play/release-notes/en-US/default.txt` | ✅ Current |

### Setup Checklist Conflict

| File | Location | Status |
|------|----------|--------|
| **Old** | `distribution/PLAY_CONSOLE_SETUP.md` | ❌ Deprecated |
| **New** | `PLAY_CONSOLE_SETUP.md` (project root) | ✅ Current |

---

## Resolution

### Decision: Standardize on GPP Conventions

**Rationale:**
- GPP is the actively maintained solution
- r0adkll action is deprecated
- GPP uses standard Android plugin conventions (`src/main/play/`)
- Simpler project structure (no `distribution/` folder needed)

---

## Changes Required

### 1. Update `android-release-notes-structure` Skill

**File:** `skills/android-release-notes-structure/SKILL.md`

**Changes:**
- Change output from `distribution/whatsnew/` to `src/main/play/release-notes/`
- Update file naming from `whatsnew` (no extension) to `default.txt`
- Remove `distribution/TRACKS.md` (move content to skill docs or separate doc)
- Update verification commands

**Old Structure:**
```
distribution/
├── whatsnew/
│   ├── en-US/
│   │   └── whatsnew
│   └── README.md
└── TRACKS.md
```

**New Structure:**
```
src/main/play/
├── release-notes/
│   ├── en-US/
│   │   └── default.txt
│   └── README.md
└── listings/           # Optional: store listing metadata
    └── en-US/
        ├── title.txt
        ├── short-description.txt
        └── full-description.txt
```

**Updated SKILL.md outputs:**
```yaml
outputs:
  - src/main/play/release-notes/ directory structure
  - docs/PLAY_STORE_TRACKS.md  # Move tracks doc to docs/
verify: "test -f src/main/play/release-notes/en-US/default.txt"
```

---

### 2. Update `android-playstore-setup/templates/RELEASE_NOTES_README.md`

**File:** `skills/android-playstore-setup/templates/RELEASE_NOTES_README.md`

**Changes:**
- Update all paths from `distribution/whatsnew/` to `src/main/play/release-notes/`
- Update file naming from `whatsnew` to `default.txt`
- Remove reference to r0adkll action
- Add GPP command reference

**Key sections to update:**

```markdown
## Directory Structure

```
src/main/play/release-notes/
├── en-US/
│   └── default.txt
├── de-DE/
│   └── default.txt
└── README.md
```

## Automation

Release notes are automatically included by Gradle Play Publisher:

```kotlin
// In app/build.gradle.kts
play {
    // GPP automatically looks for release notes in src/main/play/release-notes/
    track.set("internal")
}
```

Deployment command:
```bash
./gradlew publishReleaseBundle --track internal
```
```

---

### 3. Remove `distribution/TRACKS.md` from template, move to docs

**Current:** `skills/android-playstore-setup/templates/TRACKS.md`
**Action:** Keep as reference documentation, but don't generate into `distribution/`

**Option A:** Move content to `skills/android-playstore-setup/SKILL.md` (inline)
**Option B:** Keep as `templates/TRACKS.md` but copy to `docs/PLAY_STORE_TRACKS.md`

**Recommendation:** Option B - Keep separate for reference, output to `docs/`

---

### 4. Update `android-playstore-scan` Skill

**File:** `skills/android-playstore-scan/SKILL.md`

**Changes:**
- Confirm output is `PLAY_CONSOLE_SETUP.md` in project root (already correct)
- Remove any reference to `distribution/PLAY_CONSOLE_SETUP.md`

**Current (correct):**
```yaml
outputs:
  - PLAY_CONSOLE_SETUP.md
```

No changes needed if already outputting to root.

---

### 5. Update `android-playstore-setup` Skill

**File:** `skills/android-playstore-setup/SKILL.md`

**Changes:**
- Ensure Step 7 creates `src/main/play/release-notes/` (not `distribution/whatsnew/`)
- Remove any reference to `distribution/` folder
- Update file references in completion criteria

**Section to verify (Step 7):**
```markdown
### Step 7: Create Internal Deployment Workflows

Run `/devtools:android-workflow-internal`

**What it does:**
- Adds GPP plugin to app/build.gradle.kts
- Creates src/main/play/release-notes/en-US/default.txt  # ✅ Correct
- Creates .github/workflows/build.yml
- Creates .github/workflows/release-internal.yml
```

---

### 6. Update `android-workflow-internal` Skill

**File:** `skills/android-workflow-internal/SKILL.md`

**Changes:**
- Verify release notes creation uses `src/main/play/release-notes/`

**Current Step 2 (verify correct):**
```bash
mkdir -p src/main/play/release-notes/en-US
echo "Bug fixes and performance improvements" > src/main/play/release-notes/en-US/default.txt
```

---

### 7. Deprecation Notice for Old Skills

Add deprecation notice to any skill still using `distribution/`:

```markdown
> ⚠️ **DEPRECATED:** The `distribution/whatsnew/` structure was used with the r0adkll upload action.
> This skill now uses Gradle Play Publisher (GPP) which expects release notes in `src/main/play/release-notes/`.
> See migration guide below.
```

---

## Migration Guide for Existing Projects

For projects using old `distribution/` structure:

```bash
# 1. Create new GPP structure
mkdir -p src/main/play/release-notes/en-US

# 2. Move release notes (if any exist)
if [ -f distribution/whatsnew/en-US/whatsnew ]; then
    cp distribution/whatsnew/en-US/whatsnew src/main/play/release-notes/en-US/default.txt
fi

# 3. Move other locales
for locale_dir in distribution/whatsnew/*/; do
    locale=$(basename "$locale_dir")
    if [ "$locale" != "README.md" ] && [ -f "$locale_dir/whatsnew" ]; then
        mkdir -p "src/main/play/release-notes/$locale"
        cp "$locale_dir/whatsnew" "src/main/play/release-notes/$locale/default.txt"
    fi
done

# 4. Remove old structure (after verifying)
# rm -rf distribution/whatsnew/

# 5. Keep TRACKS.md as reference (optional)
# mv distribution/TRACKS.md docs/PLAY_STORE_TRACKS.md
```

---

## Files to Modify

| File | Action | Change |
|------|--------|--------|
| `skills/android-release-notes-structure/SKILL.md` | **UPDATE** | Change to `src/main/play/release-notes/` |
| `skills/android-playstore-setup/templates/RELEASE_NOTES_README.md` | **UPDATE** | Update paths and examples |
| `skills/android-playstore-setup/templates/TRACKS.md` | **KEEP** | Output to `docs/` instead of `distribution/` |
| `skills/android-playstore-setup/SKILL.md` | **VERIFY** | Ensure uses GPP paths |
| `skills/android-workflow-internal/SKILL.md` | **VERIFY** | Ensure uses GPP paths |
| `skills/android-playstore-scan/SKILL.md` | **VERIFY** | Outputs to root (correct) |

---

## Verification

After implementation:

```bash
# Verify no references to old distribution/whatsnew path
grep -r "distribution/whatsnew" skills/ && echo "❌ Old paths found" || echo "✅ No old paths"

# Verify GPP paths are used
grep -r "src/main/play/release-notes" skills/ && echo "✅ GPP paths found"

# Verify PLAY_CONSOLE_SETUP.md outputs to root
grep -A2 "outputs:" skills/android-playstore-scan/SKILL.md | grep "PLAY_CONSOLE_SETUP.md"
```

---

## Summary

| Item | Old Location | New Location |
|------|--------------|--------------|
| Release notes | `distribution/whatsnew/en-US/whatsnew` | `src/main/play/release-notes/en-US/default.txt` |
| Setup checklist | `distribution/PLAY_CONSOLE_SETUP.md` | `PLAY_CONSOLE_SETUP.md` (root) |
| Tracks guide | `distribution/TRACKS.md` | `docs/PLAY_STORE_TRACKS.md` |
| Release notes README | `distribution/whatsnew/README.md` | `src/main/play/release-notes/README.md` |

**Result:** Clean, consistent directory structure aligned with Gradle Play Publisher conventions.
