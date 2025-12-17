# SERVICE_ACCOUNT_JSON Rename Spec

**Purpose:** Rename `SERVICE_ACCOUNT_JSON` to `SERVICE_ACCOUNT_JSON_PLAINTEXT` for clarity
**Date:** 2025-12-16
**Status:** Ready for Implementation

---

## Overview

The GitHub secret `SERVICE_ACCOUNT_JSON` should be renamed to `SERVICE_ACCOUNT_JSON_PLAINTEXT` to make it clear that:
1. The secret contains the **plaintext JSON** (not base64 encoded)
2. It differentiates from potential future `SERVICE_ACCOUNT_JSON_BASE64` variants

---

## Files to Update

### 1. Workflow Skills (YAML templates)

| File | Occurrences |
|------|-------------|
| `skills/android-workflow-internal/SKILL.md` | 1 |
| `skills/android-workflow-beta/SKILL.md` | 2 |
| `skills/android-workflow-production/SKILL.md` | 4 |

**Pattern to replace:**
```yaml
# OLD
${{ secrets.SERVICE_ACCOUNT_JSON }}

# NEW
${{ secrets.SERVICE_ACCOUNT_JSON_PLAINTEXT }}
```

### 2. Documentation

| File | Occurrences |
|------|-------------|
| `skills/android-playstore-setup/templates/GITHUB_SECRETS.md` | Multiple |
| `skills/android-playstore-setup/SKILL.md` | Check for mentions |
| `skills/android-keystore-generation/SKILL.md` | Check for mentions |

### 3. Other potential files

Check these for mentions:
- `skills/android-service-account-guide/SKILL.md`
- `skills/android-playstore-api-validation/SKILL.md`
- `skills/android-playstore-publishing/SKILL.md`
- `docs/*.md`

---

## Detailed Changes

### android-workflow-internal/SKILL.md

**Line ~110 (Create Service Account File step):**
```yaml
# OLD
      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON }}" > service-account.json

# NEW
      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON_PLAINTEXT }}" > service-account.json
```

### android-workflow-beta/SKILL.md

**Lines ~95 and ~107 (both Deploy steps):**
```yaml
# OLD
      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON }}" > service-account.json

# NEW
      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON_PLAINTEXT }}" > service-account.json
```

### android-workflow-production/SKILL.md

**Lines ~95, ~157, ~175, ~183 (deploy-production.yml and manage-rollout.yml):**
```yaml
# OLD
      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON }}" > service-account.json

# NEW
      - name: Create Service Account File
        run: echo "${{ secrets.SERVICE_ACCOUNT_JSON_PLAINTEXT }}" > service-account.json
```

### GITHUB_SECRETS.md

**Multiple occurrences - update all:**

1. Section header:
```markdown
# OLD
### 1. SERVICE_ACCOUNT_JSON

# NEW
### 1. SERVICE_ACCOUNT_JSON_PLAINTEXT
```

2. Description:
```markdown
# OLD
**What it is:** Complete contents of the Google Cloud service account JSON file

# NEW
**What it is:** Complete plaintext contents of the Google Cloud service account JSON file (not base64 encoded)
```

3. GitHub steps:
```markdown
# OLD
4. In GitHub:
   - Name: `SERVICE_ACCOUNT_JSON`
   - Value: Paste the copied JSON

# NEW
4. In GitHub:
   - Name: `SERVICE_ACCOUNT_JSON_PLAINTEXT`
   - Value: Paste the copied JSON (plaintext, not base64 encoded)
```

4. Test workflow example:
```yaml
# OLD
      - name: Test SERVICE_ACCOUNT_JSON
        run: |
          echo "${{ secrets.SERVICE_ACCOUNT_JSON }}" | jq -r '.client_email'

# NEW
      - name: Test SERVICE_ACCOUNT_JSON_PLAINTEXT
        run: |
          echo "${{ secrets.SERVICE_ACCOUNT_JSON_PLAINTEXT }}" | jq -r '.client_email'
```

5. Common Issues section:
```markdown
# OLD
### "Invalid service account JSON"

# NEW  
### "Invalid service account JSON (SERVICE_ACCOUNT_JSON_PLAINTEXT)"
```

---

## Verification

After implementation, run:

```bash
# Check no old references remain
grep -rn "SERVICE_ACCOUNT_JSON[^_]" skills/ --include="*.md" || echo "✓ No old references"

# Verify new references exist
grep -rn "SERVICE_ACCOUNT_JSON_PLAINTEXT" skills/ --include="*.md" | head -10
```

---

## Implementation Checklist

- [ ] Update `skills/android-workflow-internal/SKILL.md`
- [ ] Update `skills/android-workflow-beta/SKILL.md`
- [ ] Update `skills/android-workflow-production/SKILL.md`
- [ ] Update `skills/android-playstore-setup/templates/GITHUB_SECRETS.md`
- [ ] Check and update `skills/android-playstore-setup/SKILL.md`
- [ ] Check and update `skills/android-service-account-guide/SKILL.md`
- [ ] Check and update any other files with mentions
- [ ] Run verification to confirm no old references remain

---

## Summary

| Old Name | New Name |
|----------|----------|
| `SERVICE_ACCOUNT_JSON` | `SERVICE_ACCOUNT_JSON_PLAINTEXT` |

This rename makes it explicitly clear that the secret should contain the raw JSON text, not a base64-encoded version.
