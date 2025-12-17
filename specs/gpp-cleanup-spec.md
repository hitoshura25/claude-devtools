# GPP to Fastlane Migration Cleanup Spec

**Purpose:** Remove all Gradle Play Publisher (GPP) references from workflow skills and replace with Fastlane
**Date:** 2025-12-15
**Status:** Ready for Implementation

---

## Overview

The workflow skills still contain GPP references that need to be replaced with Fastlane commands. This spec details the exact changes needed.

---

## Files to Update

### 1. `skills/android-workflow-internal/SKILL.md`

#### Remove/Replace:

**Step 1 - Remove GPP Plugin Configuration:**

Delete this entire section:
```markdown
### Step 1: Configure Gradle Play Publisher Plugin

Add GPP plugin to `app/build.gradle.kts`:

\`\`\`kotlin
plugins {
    id("com.android.application")
    id("com.github.triplet.play") version "3.13.0"
}

play {
    // Auth via ANDROID_PUBLISHER_CREDENTIALS env var in CI
    track.set("internal")
    defaultToAppBundles.set(true)
    // Release notes location: src/main/play/release-notes/en-US/default.txt
}
\`\`\`

**Detection logic:**
- Check if GPP plugin already exists in build.gradle.kts
- If exists, verify version is 3.13.0 or higher
- If not, add plugin configuration
```

**Replace with:**
```markdown
### Step 1: Verify Fastlane Setup

Ensure Fastlane is configured by running `/devtools:android-fastlane-setup` first.

Verify setup:
\`\`\`bash
bundle exec fastlane lanes
\`\`\`

Expected output should show `deploy_internal` lane.
```

---

**Step 2 - Remove GPP Release Notes:**

Delete:
```markdown
### Step 2: Create Release Notes Structure

\`\`\`bash
mkdir -p src/main/play/release-notes/en-US
echo "Bug fixes and performance improvements" > src/main/play/release-notes/en-US/default.txt
\`\`\`
```

**Replace with:**
```markdown
### Step 2: Verify Metadata Structure

Ensure Fastlane metadata exists:
\`\`\`bash
ls fastlane/metadata/android/en-US/
\`\`\`

If missing, run `/devtools:android-fastlane-setup`.
```

---

**In release-internal.yml workflow - Replace GPP deploy step:**

Delete:
```yaml
      - name: Deploy to Play Store (Internal)
        env:
          ANDROID_PUBLISHER_CREDENTIALS: ${{ secrets.SERVICE_ACCOUNT_JSON }}
        run: ./gradlew publishReleaseBundle --track internal
```

**Replace with:**
```yaml
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON }}" > service-account.json

      - name: Deploy with Fastlane
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/app/release.jks
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
          PLAY_STORE_SERVICE_ACCOUNT: service-account.json
        run: bundle exec fastlane deploy_internal

      - name: Cleanup Service Account
        if: always()
        run: rm -f service-account.json
```

---

**Remove GPP verification command:**

Delete:
```bash
# Verify GPP commands
grep "publishReleaseBundle" .github/workflows/release-internal.yml
```

**Replace with:**
```bash
# Verify Fastlane commands
grep "fastlane deploy_internal" .github/workflows/release-internal.yml
```

---

**Update Completion Criteria:**

Delete:
```markdown
- [ ] GPP plugin configured in app/build.gradle.kts
- [ ] Release notes directory created (src/main/play/release-notes/en-US/)
```

**Replace with:**
```markdown
- [ ] Fastlane configured (`bundle exec fastlane lanes` works)
- [ ] Metadata exists in `fastlane/metadata/android/en-US/`
```

---

### 2. `skills/android-workflow-beta/SKILL.md`

#### Remove/Replace:

**Step 1 - Remove GPP Plugin Configuration:**

Delete entire GPP plugin section and replace with:
```markdown
### Step 1: Verify Fastlane Setup

Ensure Fastlane is configured:
\`\`\`bash
bundle exec fastlane lanes
\`\`\`

Expected output should show `deploy_beta` lane.
```

---

**In deploy-beta.yml workflow - Replace GPP deploy steps:**

Delete both GPP deploy steps:
```yaml
      - name: Deploy to Play Store (Full Rollout)
        if: github.event.inputs.rollout_type == 'full'
        env:
          ANDROID_PUBLISHER_CREDENTIALS: ${{ secrets.SERVICE_ACCOUNT_JSON }}
        run: |
          ./gradlew publishReleaseBundle \
            --track ${{ github.event.inputs.track }} \
            --release-status completed

      - name: Deploy to Play Store (Staged Rollout)
        if: github.event.inputs.rollout_type == 'staged'
        env:
          ANDROID_PUBLISHER_CREDENTIALS: ${{ secrets.SERVICE_ACCOUNT_JSON }}
        run: |
          ./gradlew publishReleaseBundle \
            --track ${{ github.event.inputs.track }} \
            --release-status inProgress \
            --user-fraction ${{ github.event.inputs.rollout_percentage }}
```

**Replace with:**
```yaml
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON }}" > service-account.json

      - name: Deploy with Fastlane (Full Rollout)
        if: github.event.inputs.rollout_type == 'full'
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/app/release.jks
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
          PLAY_STORE_SERVICE_ACCOUNT: service-account.json
        run: bundle exec fastlane deploy_beta

      - name: Deploy with Fastlane (Staged Rollout)
        if: github.event.inputs.rollout_type == 'staged'
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/app/release.jks
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
          PLAY_STORE_SERVICE_ACCOUNT: service-account.json
        run: bundle exec fastlane deploy_beta rollout:${{ github.event.inputs.rollout_percentage }}

      - name: Cleanup Service Account
        if: always()
        run: rm -f service-account.json
```

---

**Remove GPP migration notes:**

Delete:
```markdown
**Important changes:**
- ✅ Fixed userFraction issue: Now uses separate deploy steps for full vs. staged rollouts
- ✅ When `rollout_type: full`, uses `--release-status completed` (NO userFraction)
- ✅ When `rollout_type: staged`, uses `--release-status inProgress` with `--user-fraction`
- ✅ Migrated to GPP (Gradle Play Publisher)
```

**Replace with:**
```markdown
**Key features:**
- ✅ Uses Fastlane for deployment
- ✅ Supports full and staged rollouts
- ✅ Pinned all actions to commit SHAs
- ✅ Test job runs before deployment
```

---

### 3. `skills/android-workflow-production/SKILL.md`

#### Remove/Replace:

**Step 1 - Remove GPP Plugin Configuration:**

Delete entire GPP plugin section and replace with:
```markdown
### Step 1: Verify Fastlane Setup

Ensure Fastlane is configured:
\`\`\`bash
bundle exec fastlane lanes
\`\`\`

Expected output should show `deploy_production`, `increase_rollout`, and `halt_rollout` lanes.
```

---

**In deploy-production.yml workflow - Replace GPP deploy steps:**

Delete both GPP deploy steps and replace with Fastlane:
```yaml
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON }}" > service-account.json

      - name: Deploy with Fastlane (Full Rollout)
        if: github.event.inputs.rollout_type == 'full'
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/app/release.jks
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
          PLAY_STORE_SERVICE_ACCOUNT: service-account.json
        run: bundle exec fastlane deploy_production rollout:1.0

      - name: Deploy with Fastlane (Staged Rollout)
        if: github.event.inputs.rollout_type == 'staged'
        env:
          SIGNING_KEY_STORE_PATH: ${{ github.workspace }}/app/release.jks
          SIGNING_STORE_PASSWORD: ${{ secrets.SIGNING_STORE_PASSWORD }}
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
          PLAY_STORE_SERVICE_ACCOUNT: service-account.json
        run: bundle exec fastlane deploy_production rollout:${{ github.event.inputs.rollout_percentage }}

      - name: Cleanup Service Account
        if: always()
        run: rm -f service-account.json
```

---

**In manage-rollout.yml workflow - Replace GPP commands:**

Delete GPP-based promote/complete steps:
```yaml
      - name: Promote to Production (Staged)
        if: github.event.inputs.action == 'promote'
        env:
          ANDROID_PUBLISHER_CREDENTIALS: ${{ secrets.SERVICE_ACCOUNT_JSON }}
        run: |
          ./gradlew promoteReleaseArtifact \
            --from-track ${{ github.event.inputs.from_track }} \
            --promote-track production \
            --release-status inProgress \
            --user-fraction ${{ github.event.inputs.percentage }}

      - name: Complete Rollout (100%)
        if: github.event.inputs.action == 'complete'
        env:
          ANDROID_PUBLISHER_CREDENTIALS: ${{ secrets.SERVICE_ACCOUNT_JSON }}
        run: |
          ./gradlew promoteReleaseArtifact \
            --from-track production \
            --promote-track production \
            --release-status completed
```

**Replace with:**
```yaml
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON }}" > service-account.json

      - name: Increase Rollout
        if: github.event.inputs.action == 'promote'
        env:
          PLAY_STORE_SERVICE_ACCOUNT: service-account.json
        run: bundle exec fastlane increase_rollout rollout:${{ github.event.inputs.percentage }}

      - name: Complete Rollout (100%)
        if: github.event.inputs.action == 'complete'
        env:
          PLAY_STORE_SERVICE_ACCOUNT: service-account.json
        run: bundle exec fastlane increase_rollout rollout:1.0

      - name: Halt Rollout
        if: github.event.inputs.action == 'halt'
        env:
          PLAY_STORE_SERVICE_ACCOUNT: service-account.json
        run: bundle exec fastlane halt_rollout

      - name: Cleanup Service Account
        if: always()
        run: rm -f service-account.json
```

---

**Remove GPP migration notes:**

Delete all references to:
- "Migrated to GPP (Gradle Play Publisher)"
- "GPP does not support..."
- "Uses GPP commands where supported"

---

### 4. Update `skills/android-playstore-setup/SKILL.md`

Remove any remaining GPP references and ensure it points to Fastlane setup.

Search for and remove/replace:
- `gradle-play-publisher`
- `triplet.play`
- `publishReleaseBundle`
- `GPP`
- `Gradle Play Publisher`
- `src/main/play/release-notes`

Replace release notes path references:
- Old: `src/main/play/release-notes/en-US/default.txt`
- New: `fastlane/metadata/android/en-US/changelogs/default.txt`

---

### 5. Update `skills/android-release-notes-structure/SKILL.md`

This skill may still reference GPP paths. Update to use Fastlane metadata structure:

- Old path: `src/main/play/release-notes/`
- New path: `fastlane/metadata/android/{locale}/changelogs/`

---

### 6. Check and Update Templates

#### `skills/android-playstore-setup/templates/RELEASE_NOTES_README.md`

Remove any GPP references and update paths to Fastlane structure.

---

## Verification Commands

After implementation, run these to verify no GPP references remain:

```bash
# Check for GPP plugin references
grep -rn "triplet.play\|gradle-play-publisher" skills/ --include="*.md"
# Expected: No results

# Check for GPP commands
grep -rn "publishReleaseBundle\|promoteReleaseArtifact" skills/ --include="*.md"
# Expected: No results

# Check for GPP acronym
grep -rn "GPP" skills/ --include="*.md"
# Expected: No results (or only in historical context explaining migration)

# Check for old release notes path
grep -rn "src/main/play/release-notes" skills/ --include="*.md"
# Expected: No results

# Verify Fastlane references exist
grep -rn "bundle exec fastlane\|fastlane deploy" skills/ --include="*.md"
# Expected: Multiple results in workflow skills
```

---

## Implementation Checklist

- [ ] Update `skills/android-workflow-internal/SKILL.md`
  - [ ] Remove GPP plugin configuration section
  - [ ] Remove GPP release notes section
  - [ ] Update workflow YAML to use Fastlane
  - [ ] Update verification commands
  - [ ] Update completion criteria

- [ ] Update `skills/android-workflow-beta/SKILL.md`
  - [ ] Remove GPP plugin configuration section
  - [ ] Update workflow YAML to use Fastlane
  - [ ] Remove GPP migration notes

- [ ] Update `skills/android-workflow-production/SKILL.md`
  - [ ] Remove GPP plugin configuration section
  - [ ] Update deploy-production.yml to use Fastlane
  - [ ] Update manage-rollout.yml to use Fastlane
  - [ ] Remove GPP migration notes

- [ ] Update `skills/android-playstore-setup/SKILL.md`
  - [ ] Remove any GPP references
  - [ ] Update to reference Fastlane setup

- [ ] Update `skills/android-release-notes-structure/SKILL.md`
  - [ ] Update paths to Fastlane metadata structure

- [ ] Update templates
  - [ ] `skills/android-playstore-setup/templates/RELEASE_NOTES_README.md`

- [ ] Run verification commands to confirm cleanup complete

---

## Summary

This cleanup removes all traces of GPP and ensures consistency with the new Fastlane-based deployment approach.

| Before | After |
|--------|-------|
| `./gradlew publishReleaseBundle` | `bundle exec fastlane deploy_internal` |
| `./gradlew promoteReleaseArtifact` | `bundle exec fastlane increase_rollout` |
| `src/main/play/release-notes/` | `fastlane/metadata/android/{locale}/changelogs/` |
| `ANDROID_PUBLISHER_CREDENTIALS` | `PLAY_STORE_SERVICE_ACCOUNT` |
| GPP plugin in build.gradle.kts | Fastlane Gemfile + Fastfile |
