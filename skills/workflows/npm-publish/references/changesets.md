# Changesets Guide

Changesets manages versioning and changelogs in monorepos.

## Creating Changesets

### Interactive Method

```bash
pnpm changeset
```

Prompts for:
1. Which packages changed
2. Version bump type (major/minor/patch)
3. Summary for changelog

### Manual Method (Claude Code)

Create `.changeset/random-name.md`:

```markdown
---
"@scope/package-name": patch
---

Description for CHANGELOG
```

**Filename:** Use any random name (avoid conflicts):
- `happy-cats-jump.md`
- `fix-icon-bug.md`
- `add-new-feature.md`

### Empty Changeset

For changes that don't need a release:

```bash
pnpm changeset --empty
```

Or manually:

```markdown
---
---

Update CI workflow
```

## Changeset Format

### Single Package

```markdown
---
"@scope/cli": minor
---

Add new command for feature X
```

### Multiple Packages

```markdown
---
"@scope/core": patch
"@scope/cli": minor
---

Add CLI command using new core utility
```

### Version Bump Types

| Type | When to Use | Example |
|------|-------------|---------|
| `patch` | Bug fixes, docs | 1.0.0 → 1.0.1 |
| `minor` | New features (backward compatible) | 1.0.0 → 1.1.0 |
| `major` | Breaking changes | 1.0.0 → 2.0.0 |

## Configuration

### .changeset/config.json

```json
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [],
  "linked": [],
  "access": "public",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
```

### Options Explained

**`access`:** Package visibility
- `"public"` - Required for scoped packages (@scope/name)
- `"restricted"` - Private packages (paid npm)

**`updateInternalDependencies`:** When package A depends on B:
- `"patch"` - Bump A when B changes (recommended)
- `"minor"` - Only bump A for minor+ changes to B
- `"major"` - Only bump A for major changes to B

**`linked`:** Packages that always have same version:
```json
{
  "linked": [["@scope/react", "@scope/react-dom"]]
}
```

**`fixed`:** Packages with identical versions (stricter than linked):
```json
{
  "fixed": [["@scope/core", "@scope/utils"]]
}
```

**`ignore`:** Packages to exclude from changesets:
```json
{
  "ignore": ["@scope/internal-tool"]
}
```

## Workflow Integration

### Pre-commit Hook

Enforce changesets with Husky:

```bash
# .husky/pre-commit
CHANGESET_FILES=$(find .changeset -name '*.md' ! -name 'README.md' | wc -l)
if [ "$CHANGESET_FILES" -eq 0 ]; then
  echo "❌ No changeset found!"
  exit 1
fi
```

### CI: Create Version PR

```yaml
- uses: changesets/action@v1
  with:
    version: pnpm changeset version
    publish: pnpm release
    commit: "Version Packages"
    title: "Version Packages"
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### CI: Publish Packages

The `changesets/action` automatically:
1. Detects pending changesets
2. Creates "Version Packages" PR with bumped versions
3. On merge, publishes all changed packages

## Commands Reference

```bash
# Create changeset (interactive)
pnpm changeset

# Create empty changeset
pnpm changeset --empty

# Preview version bumps (dry run)
pnpm changeset version

# Check changeset status
pnpm changeset status

# Publish packages (usually via CI)
pnpm changeset publish
```

## Troubleshooting

### "No packages selected"

When `pnpm changeset` shows no packages:
- Ensure packages aren't in `ignore` list
- Check package isn't `private: true` (unless intentional)

### Pre-commit Hook Blocks Commit

Create a changeset:
```bash
pnpm changeset
# Select affected packages
# Choose version bump
# Write summary
```

Or for non-release changes:
```bash
pnpm changeset --empty
```

### Version Packages PR Not Created

Check:
1. Changesets exist in `.changeset/`
2. GitHub Actions has write permissions
3. `GITHUB_TOKEN` secret is available
