# npm Monorepo Publishing - Implementation Spec

> **For Claude Code:** Use `superpowers:executing-plans` to implement this spec task-by-task.

**Goal:** Expand the npm-publish skill with comprehensive monorepo support using pnpm workspaces, Turborepo, Changesets, and NPM Trusted Publishing with OIDC.

**Source of Truth:** `~/devtools-mcp` - A working monorepo using these exact patterns.

**Architecture:**
- Update `skills/workflows/npm-publish/SKILL.md` with monorepo workflow
- Add detailed reference files for each component
- Patterns extracted from real working code, not theoretical examples

---

## Phase 1: Update Core Skill

### Task 1.1: Rewrite npm-publish SKILL.md

**Files:**
- Modify: `skills/workflows/npm-publish/SKILL.md`

**Step 1: Replace entire SKILL.md content**

Write to `skills/workflows/npm-publish/SKILL.md`:

```markdown
---
name: npm-publish
description: Use when publishing npm packages, especially from pnpm/Turborepo monorepos with Changesets
---

# npm Publish

## Overview

Publish npm packages with Changesets versioning, Turborepo builds, and automated CI/CD. Supports both single packages and monorepos.

## Prerequisites

- **Quality gates passed:** All tests, lint, security must pass
- **npm account:** With publish access to package scope
- **Changesets:** For version management (monorepos)
- **CI/CD:** GitHub Actions with NPM Trusted Publishing (recommended)

## The Rule

```
NO PUBLISH WITHOUT:
1. Changeset created for the change
2. All quality gates passing
3. Version Packages PR merged (monorepos)
```

## Monorepo vs Single Package

| Aspect | Single Package | Monorepo |
|--------|---------------|----------|
| Version management | `npm version` | Changesets |
| Build orchestration | `npm run build` | Turborepo |
| Publishing | `npm publish` | `pnpm release` via CI |
| Dependency management | npm/yarn | pnpm workspaces |

## Monorepo Workflow (Recommended)

### 1. Create Changeset

After making changes, create a changeset file:

```bash
# Interactive (if available)
pnpm changeset

# Or manually create .changeset/random-name.md
```

**Changeset format:**
```markdown
---
"@scope/package-name": patch
---

Brief description for CHANGELOG
```

**Version bump types:**
- `patch` - Bug fixes (0.1.2 → 0.1.3)
- `minor` - New features (0.1.0 → 0.2.0)  
- `major` - Breaking changes (1.0.0 → 2.0.0)

**Multiple packages:**
```markdown
---
"@scope/core": patch
"@scope/cli": minor
---

Add CLI feature with core bugfix
```

**Empty changeset (no release needed):**
```markdown
---
---

Update CI workflow (no package changes)
```

### 2. Commit and Push

```bash
git add .
git commit -m "feat: add feature"
git push origin feature-branch
```

Pre-commit hook enforces changeset exists.

### 3. Merge PR to Main

CI runs tests → PR merged → CI creates "Version Packages" PR automatically.

### 4. Version Packages PR

Changesets action:
- Bumps versions in all affected package.json files
- Updates CHANGELOG.md files
- Creates PR titled "Version Packages"

### 5. Merge Version Packages PR

Once merged:
- CI publishes all changed packages to npm
- Uses OIDC (no tokens needed) for existing packages
- Falls back to NPM_TOKEN for first publish of new packages

### 6. Verify Publication

```bash
# Check published version
npm view @scope/package-name version

# Verify provenance (OIDC)
npm view @scope/package-name --json | jq '.provenance'
```

## Single Package Workflow

For non-monorepo packages:

### 1. Verify Quality Gates

```bash
npm test
npm run lint
npm audit --audit-level=high
```

### 2. Bump Version

```bash
npm version patch  # or minor/major
```

### 3. Build and Publish

```bash
npm run build
npm publish
```

### 4. Push Tags

```bash
git push origin main --tags
```

## CI/CD Configuration

**Required secrets:**
- `NPM_PUBLISH_TOKEN` - For first publish of new packages
- `RELEASE_BOT_APP_ID` + `RELEASE_BOT_PRIVATE_KEY` - For Version Packages PR

**OIDC setup (per package):**
1. Publish package once (uses NPM_TOKEN)
2. Go to npmjs.com → Package → Settings → Trusted Publishers
3. Add GitHub Actions publisher with workflow filename

See `references/trusted-publishing.md` for detailed setup.

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Just a small fix" | Still needs changeset. Pre-commit hook enforces it. |
| "Changeset is annoying" | 10 seconds to create. Prevents version chaos. |
| "I'll version manually" | Manual versioning breaks in monorepos. Use Changesets. |
| "NPM_TOKEN is easier" | OIDC is more secure. No token rotation needed. |
| "Skip CI for speed" | CI prevents broken publishes. Never skip. |

## Red Flags - STOP

- Committing without changeset (hook will block anyway)
- Publishing locally instead of via CI
- Using `--force` to bypass checks
- Manually editing version numbers
- Skipping the Version Packages PR

**If you catch yourself doing any of these: STOP. Follow the process.**

## Verification

```bash
# Verify changeset exists
ls .changeset/*.md | grep -v README

# Verify package on npm
npm view @scope/package-name version

# Verify provenance
npm view @scope/package-name --json | jq '.provenance'
```

## References

- `references/monorepo-setup.md` - pnpm + Turborepo + Changesets setup
- `references/changesets.md` - Changeset creation and configuration
- `references/trusted-publishing.md` - NPM OIDC setup
- `references/ci-workflows.md` - GitHub Actions configuration
- `references/package-config.md` - package.json best practices
```

**Step 2: Commit**

```bash
git add skills/workflows/npm-publish/SKILL.md
git commit -m "feat(npm-publish): rewrite with monorepo workflow"
```

---

## Phase 2: Monorepo Setup Reference

### Task 2.1: Create monorepo-setup.md

**Files:**
- Create: `skills/workflows/npm-publish/references/monorepo-setup.md`

**Step 1: Write monorepo-setup.md**

Write to `skills/workflows/npm-publish/references/monorepo-setup.md`:

```markdown
# Monorepo Setup Guide

Complete setup for pnpm workspaces + Turborepo + Changesets monorepo.

## Directory Structure

```
my-monorepo/
├── .changeset/
│   ├── config.json
│   └── README.md
├── .github/
│   └── workflows/
│       └── ci.yml
├── .husky/
│   └── pre-commit
├── packages/
│   ├── core/
│   │   ├── package.json
│   │   ├── src/
│   │   └── tsconfig.json
│   └── cli/
│       ├── package.json
│       ├── src/
│       └── tsconfig.json
├── package.json
├── pnpm-lock.yaml
├── pnpm-workspace.yaml
├── tsconfig.base.json
└── turbo.json
```

## Step 1: Initialize pnpm Workspace

### Root package.json

```json
{
  "name": "my-monorepo",
  "version": "0.0.0",
  "private": true,
  "description": "My monorepo",
  "scripts": {
    "build": "turbo run build",
    "test": "turbo run test",
    "lint": "turbo run lint",
    "clean": "turbo run clean",
    "release": "pnpm publish -r --provenance",
    "prepare": "husky"
  },
  "devDependencies": {
    "@changesets/cli": "^2.27.0",
    "@types/node": "^20.0.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "eslint": "^8.0.0",
    "husky": "^9.1.7",
    "turbo": "^2.0.0",
    "typescript": "^5.4.0",
    "vitest": "^1.6.0"
  },
  "packageManager": "pnpm@9.0.0",
  "engines": {
    "node": ">=20.0.0",
    "pnpm": ">=9.0.0"
  }
}
```

### pnpm-workspace.yaml

```yaml
packages:
  - 'packages/*'
```

## Step 2: Configure Turborepo

### turbo.json

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": []
    },
    "lint": {
      "outputs": []
    },
    "clean": {
      "cache": false
    }
  }
}
```

**Key concepts:**
- `^build` - Build dependencies first (topological order)
- `outputs` - What to cache
- `dependsOn` - Task dependencies

## Step 3: Configure Changesets

### Initialize

```bash
pnpm changeset init
```

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

**Options:**
- `access: "public"` - Required for scoped packages
- `updateInternalDependencies: "patch"` - Auto-bump dependents
- `linked: []` - Packages that version together
- `fixed: []` - Packages with identical versions

## Step 4: Configure Husky

### Install and Initialize

```bash
pnpm add -D husky
pnpm exec husky init
```

### .husky/pre-commit

```bash
#!/usr/bin/env sh
set -eu

echo "🔍 Checking for changesets..."

# Skip in CI
if [ -n "${CI:-}" ]; then
  echo "✅ Skipping changeset check (CI)"
  exit 0
fi

# Get staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

# Skip docs-only changes
MEANINGFUL_FILES=$(echo "$STAGED_FILES" | grep -vE '^(\.changeset/.*\.md$|docs/|^README\.md$)' || true)

# Skip on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ -z "$MEANINGFUL_FILES" ] || [ "$CURRENT_BRANCH" = "main" ]; then
  echo "✅ Skipping changeset check"
  exit 0
fi

# Check for changeset files
CHANGESET_FILES=$(find .changeset -name '*.md' ! -name 'README.md' 2>/dev/null | wc -l | xargs)

if [ "$CHANGESET_FILES" -gt 0 ]; then
  echo "✅ Changeset found!"
  exit 0
fi

echo ""
echo "❌ No changeset found!"
echo ""
echo "Create a changeset:"
echo "  pnpm changeset"
echo ""
echo "Or empty changeset for non-release changes:"
echo "  pnpm changeset --empty"
echo ""
exit 1
```

## Step 5: Create Package

### packages/core/package.json

```json
{
  "name": "@scope/core",
  "version": "0.1.0",
  "description": "Core utilities",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": "./dist/index.js"
  },
  "files": ["dist"],
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "lint": "eslint src/",
    "clean": "rm -rf dist"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "vitest": "^1.6.0"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/user/my-monorepo"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

**Required fields for publishing:**
- `repository` - Required for OIDC
- `publishConfig.access: "public"` - Required for scoped packages
- `files` - What to include in package

### Workspace Dependencies

To depend on sibling packages:

```json
{
  "dependencies": {
    "@scope/core": "workspace:*"
  }
}
```

`workspace:*` resolves to actual version during publish.

## Step 6: TypeScript Configuration

### tsconfig.base.json (root)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

### packages/core/tsconfig.json

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

## Verification

```bash
# Install dependencies
pnpm install

# Build all packages
pnpm build

# Run tests
pnpm test

# Create changeset
pnpm changeset

# Verify workspace
pnpm list --recursive
```
```

**Step 2: Commit**

```bash
git add skills/workflows/npm-publish/references/monorepo-setup.md
git commit -m "docs(npm-publish): add monorepo setup guide"
```

---

## Phase 3: Changesets Reference

### Task 3.1: Create changesets.md

**Files:**
- Create: `skills/workflows/npm-publish/references/changesets.md`

**Step 1: Write changesets.md**

Write to `skills/workflows/npm-publish/references/changesets.md`:

```markdown
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
```

**Step 2: Commit**

```bash
git add skills/workflows/npm-publish/references/changesets.md
git commit -m "docs(npm-publish): add changesets guide"
```

---

## Phase 4: Trusted Publishing Reference

### Task 4.1: Create trusted-publishing.md

**Files:**
- Create: `skills/workflows/npm-publish/references/trusted-publishing.md`

**Step 1: Write trusted-publishing.md**

Write to `skills/workflows/npm-publish/references/trusted-publishing.md`:

```markdown
# NPM Trusted Publishing with OIDC

Secure, token-less publishing from GitHub Actions using OpenID Connect.

## Benefits

- ✅ No long-lived tokens to manage or rotate
- ✅ Short-lived, workflow-specific credentials
- ✅ Automatic provenance attestation
- ✅ Supply chain security verification

## How It Works

```
GitHub Actions → Request OIDC token → GitHub OIDC Provider
                                              ↓
                                        Return signed token
                                              ↓
GitHub Actions → Publish with token → npm Registry
                                              ↓
npm Registry → Verify signature → GitHub OIDC Provider
                                              ↓
                                        Token valid ✓
                                              ↓
npm Registry → Publish with provenance
```

## Self-Bootstrapping Workflow

The recommended approach handles both new and existing packages:

### For New Packages (First Publish)
1. Workflow detects package doesn't exist on npm
2. Uses `NPM_PUBLISH_TOKEN` for initial publish
3. Logs npm settings URL
4. **Action Required:** Configure OIDC on npmjs.com

### For Existing Packages
1. Workflow detects package exists
2. Uses OIDC if configured
3. Falls back to `NPM_PUBLISH_TOKEN` if not

### After OIDC Configuration
1. All publishes use OIDC automatically
2. No token needed
3. Provenance generated

## Setup Instructions

### Step 1: Create NPM Automation Token

1. Go to npmjs.com → Account → Access Tokens
2. Generate **Automation** token (not Granular)
3. Add to GitHub repository secrets as `NPM_PUBLISH_TOKEN`

### Step 2: Configure CI Workflow

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      id-token: write  # Required for OIDC
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      # Check if any packages are new (need NPM_TOKEN)
      - name: Check package registry status
        id: check-packages
        run: |
          PACKAGES=$(pnpm list -r --depth -1 --json | jq -r '.[] | select(.private != true) | .name')
          NEW_PACKAGES=""
          for PKG in $PACKAGES; do
            if ! npm view "$PKG" version &>/dev/null; then
              NEW_PACKAGES="$NEW_PACKAGES $PKG"
            fi
          done
          if [ -n "$NEW_PACKAGES" ]; then
            echo "has_new_packages=true" >> $GITHUB_OUTPUT
          else
            echo "has_new_packages=false" >> $GITHUB_OUTPUT
          fi

      # Configure npm auth for new packages
      - name: Configure npm authentication
        if: steps.check-packages.outputs.has_new_packages == 'true'
        run: |
          echo "//registry.npmjs.org/:_authToken=${NPM_PUBLISH_TOKEN}" > ~/.npmrc
        env:
          NPM_PUBLISH_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}

      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - run: pnpm test

      - uses: changesets/action@v1
        with:
          version: pnpm changeset version
          publish: pnpm release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Step 3: First Publish

Merge a changeset to main. CI will:
1. Detect new package
2. Use NPM_TOKEN
3. Publish successfully

### Step 4: Configure OIDC on npmjs.com

After first publish:

1. Go to `https://www.npmjs.com/package/@scope/package-name/settings`
2. Scroll to **Trusted Publishers**
3. Click **Add a publisher**
4. Select **GitHub Actions**
5. Fill in:

| Field | Value |
|-------|-------|
| Organization or Username | `your-github-username` |
| Repository | `your-repo-name` |
| Workflow filename | `ci.yml` |
| Environment | *(leave empty)* |

6. Click **Add trusted publisher**

### Step 5: Verify OIDC

Next publish will:
1. Use OIDC automatically
2. Generate provenance

Verify:
```bash
npm view @scope/package-name --json | jq '.provenance'
```

## Package Configuration

Required fields in package.json for OIDC:

```json
{
  "name": "@scope/package-name",
  "repository": {
    "type": "git",
    "url": "https://github.com/user/repo"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

## Verification Script

Check OIDC status for all packages:

```bash
#!/bin/bash
for PKG_DIR in packages/*; do
  if [ -f "$PKG_DIR/package.json" ]; then
    PKG_NAME=$(jq -r '.name' "$PKG_DIR/package.json")
    IS_PRIVATE=$(jq -r '.private // false' "$PKG_DIR/package.json")
    
    if [ "$IS_PRIVATE" = "true" ]; then
      echo "⊘ $PKG_NAME (private)"
      continue
    fi
    
    if npm view "$PKG_NAME" version &>/dev/null; then
      PROV=$(npm view "$PKG_NAME" --json 2>&1 | jq -e '.provenance' 2>&1)
      if [ $? -eq 0 ]; then
        echo "✓ $PKG_NAME (OIDC configured)"
      else
        echo "⚠ $PKG_NAME (needs OIDC setup)"
        echo "  → https://www.npmjs.com/package/$PKG_NAME/settings"
      fi
    else
      echo "○ $PKG_NAME (not published yet)"
    fi
  fi
done
```

## Troubleshooting

### "No valid authentication token"

Both OIDC and NPM_TOKEN failed.

**Fix:**
1. Verify `NPM_PUBLISH_TOKEN` secret exists
2. Token has publish permissions
3. For existing packages, verify OIDC configured

### "Workflow name mismatch"

OIDC workflow filename doesn't match npm settings.

**Fix:** Ensure workflow filename in npm settings matches exactly (e.g., `ci.yml`)

### Provenance Not Showing

OIDC may be configured but provenance not generated.

**Fix:**
1. Ensure `id-token: write` permission in workflow
2. Use npm CLI 11.5+ (GitHub runners have this)
3. Use `--provenance` flag: `pnpm release --provenance`
```

**Step 2: Commit**

```bash
git add skills/workflows/npm-publish/references/trusted-publishing.md
git commit -m "docs(npm-publish): add OIDC trusted publishing guide"
```

---

## Phase 5: CI Workflows Reference

### Task 5.1: Create ci-workflows.md

**Files:**
- Create: `skills/workflows/npm-publish/references/ci-workflows.md`

**Step 1: Write ci-workflows.md**

Write to `skills/workflows/npm-publish/references/ci-workflows.md`:

```markdown
# GitHub Actions CI/CD Workflows

Complete CI/CD setup for npm monorepo with Changesets.

## Workflow Overview

```
Feature PR → CI (test/lint/build)
    ↓
Merge to main → CI creates "Version Packages" PR
    ↓
Merge Version PR → CI publishes to npm
```

## Main CI Workflow

### .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build
        run: pnpm build

      - name: Lint
        run: pnpm lint

      - name: Test
        run: pnpm test

  release:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: [test]
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          ref: main

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      # Check for new packages needing NPM_TOKEN
      - name: Check package registry status
        id: check-packages
        run: |
          PACKAGES=$(pnpm list -r --depth -1 --json 2>/dev/null | jq -r '.[] | select(.private != true) | .name')
          NEW=""
          for PKG in $PACKAGES; do
            if [ -n "$PKG" ] && ! npm view "$PKG" version &>/dev/null; then
              NEW="$NEW $PKG"
            fi
          done
          if [ -n "$NEW" ]; then
            echo "has_new_packages=true" >> $GITHUB_OUTPUT
          else
            echo "has_new_packages=false" >> $GITHUB_OUTPUT
          fi

      - name: Configure npm for new packages
        if: steps.check-packages.outputs.has_new_packages == 'true'
        run: echo "//registry.npmjs.org/:_authToken=${NPM_PUBLISH_TOKEN}" > ~/.npmrc
        env:
          NPM_PUBLISH_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}

      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - name: Create Release PR or Publish
        id: changeset
        uses: changesets/action@v1
        with:
          version: pnpm changeset version
          publish: pnpm release
          commit: "Version Packages"
          title: "Version Packages"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      # Optional: Auto-merge Version PR
      - name: Enable auto-merge
        if: steps.changeset.outputs.pullRequestNumber != ''
        run: gh pr merge --auto --squash "${{ steps.changeset.outputs.pullRequestNumber }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Using GitHub App for PRs

For better security, use a GitHub App instead of `GITHUB_TOKEN`:

```yaml
- name: Generate token
  id: generate-token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.RELEASE_BOT_APP_ID }}
    private-key: ${{ secrets.RELEASE_BOT_PRIVATE_KEY }}

- uses: changesets/action@v1
  env:
    GITHUB_TOKEN: ${{ steps.generate-token.outputs.token }}
```

### Creating a GitHub App

1. Go to GitHub → Settings → Developer settings → GitHub Apps
2. Create new app with permissions:
   - Contents: Read and write
   - Pull requests: Read and write
   - Metadata: Read-only
3. Generate private key
4. Add to repository secrets:
   - `RELEASE_BOT_APP_ID`
   - `RELEASE_BOT_PRIVATE_KEY`

## Auto-Approve Workflow (Optional)

Auto-approve Version Packages PRs:

### .github/workflows/auto-approve.yml

```yaml
name: Auto-approve Version Packages

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    if: |
      github.event.pull_request.user.login == 'github-actions[bot]' &&
      github.event.pull_request.title == 'Version Packages'
    permissions:
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Auto-approve
        run: gh pr review "${{ github.event.pull_request.number }}" --approve
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Required Secrets

| Secret | Purpose | Required |
|--------|---------|----------|
| `NPM_PUBLISH_TOKEN` | First publish of new packages | Yes |
| `RELEASE_BOT_APP_ID` | GitHub App for PRs | Optional |
| `RELEASE_BOT_PRIVATE_KEY` | GitHub App for PRs | Optional |

## Branch Protection

Recommended settings for `main`:

- ✅ Require status checks (test job)
- ✅ Require branches to be up to date
- ✅ Require pull request reviews
- ✅ Allow auto-merge

## Workflow Outputs

The `changesets/action` provides outputs:

```yaml
- uses: changesets/action@v1
  id: changeset

# Available outputs:
# steps.changeset.outputs.published - "true" if packages were published
# steps.changeset.outputs.publishedPackages - JSON array of published packages
# steps.changeset.outputs.hasChangesets - "true" if pending changesets exist
# steps.changeset.outputs.pullRequestNumber - PR number if created
```

## Debugging

### View Workflow Logs

1. Go to repository → Actions
2. Click failed workflow
3. Expand failed step

### Common Issues

**"Nothing to publish"**
- No changesets exist
- Changesets already consumed by Version PR

**"Permission denied"**
- Check `permissions` block in workflow
- Verify secrets exist

**"Version Packages PR not created"**
- Verify `GITHUB_TOKEN` has write permissions
- Check branch protection rules
```

**Step 2: Commit**

```bash
git add skills/workflows/npm-publish/references/ci-workflows.md
git commit -m "docs(npm-publish): add CI workflows guide"
```

---

## Phase 6: Package Configuration Reference

### Task 6.1: Update package-config.md

**Files:**
- Modify: `skills/workflows/npm-publish/references/setup.md` → rename to `package-config.md`

**Step 1: Rename and rewrite**

```bash
mv skills/workflows/npm-publish/references/setup.md skills/workflows/npm-publish/references/package-config.md
```

Write to `skills/workflows/npm-publish/references/package-config.md`:

```markdown
# Package Configuration Reference

Best practices for package.json configuration in monorepos.

## Essential Fields

### Minimal Publishable Package

```json
{
  "name": "@scope/package-name",
  "version": "1.0.0",
  "description": "What this package does",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "files": ["dist"],
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "lint": "eslint src/"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/user/repo"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

## Field Reference

### Identity

```json
{
  "name": "@scope/package-name",
  "version": "1.0.0",
  "description": "Brief description"
}
```

- **name:** Use scope for organization packages
- **version:** Managed by Changesets (don't edit manually)
- **description:** Shown on npmjs.com

### Entry Points

```json
{
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": "./dist/index.js",
    "./utils": "./dist/utils.js"
  }
}
```

- **type:** `"module"` for ESM, omit for CommonJS
- **main:** Primary entry point
- **types:** TypeScript definitions
- **exports:** Subpath exports (modern)

### CLI Packages

```json
{
  "bin": {
    "my-cli": "./dist/cli.js",
    "my-cli-alt": "./dist/alt.js"
  }
}
```

Ensure CLI files have shebang:
```javascript
#!/usr/bin/env node
```

### Files to Publish

```json
{
  "files": [
    "dist",
    "README.md"
  ]
}
```

**Always include:** Built output, README
**Never include:** Source, tests, configs (automatic via .npmignore defaults)

Preview what's included:
```bash
npm pack --dry-run
```

### Dependencies

```json
{
  "dependencies": {
    "lodash": "^4.17.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "vitest": "^1.0.0"
  },
  "peerDependencies": {
    "react": ">=18.0.0"
  }
}
```

- **dependencies:** Required at runtime
- **devDependencies:** Build/test only
- **peerDependencies:** User must provide

### Workspace Dependencies

```json
{
  "dependencies": {
    "@scope/core": "workspace:*"
  }
}
```

`workspace:*` → Resolves to actual version during publish

### Repository (Required for OIDC)

```json
{
  "repository": {
    "type": "git",
    "url": "https://github.com/user/repo"
  }
}
```

### Publish Config

```json
{
  "publishConfig": {
    "access": "public",
    "registry": "https://registry.npmjs.org/"
  }
}
```

- **access:** `"public"` required for scoped packages
- **registry:** Usually not needed (defaults to npm)

### Metadata

```json
{
  "keywords": ["keyword1", "keyword2"],
  "author": "Name <email@example.com>",
  "license": "MIT",
  "homepage": "https://example.com",
  "bugs": {
    "url": "https://github.com/user/repo/issues"
  }
}
```

### Engines

```json
{
  "engines": {
    "node": ">=20.0.0"
  }
}
```

## Subpath Exports

Modern way to expose multiple entry points:

```json
{
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js",
      "require": "./dist/index.cjs"
    },
    "./utils": {
      "types": "./dist/utils.d.ts",
      "import": "./dist/utils.js"
    },
    "./package.json": "./package.json"
  }
}
```

Usage:
```javascript
import { main } from '@scope/package';
import { helper } from '@scope/package/utils';
```

## Private Packages

For internal packages that shouldn't be published:

```json
{
  "private": true
}
```

Changesets will ignore private packages.

## Scripts

### Standard Scripts

```json
{
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint src/",
    "clean": "rm -rf dist",
    "prepublishOnly": "npm run build && npm test"
  }
}
```

- **prepublishOnly:** Runs before `npm publish` (safety net)

### Monorepo Scripts (Root)

```json
{
  "scripts": {
    "build": "turbo run build",
    "test": "turbo run test",
    "lint": "turbo run lint",
    "release": "pnpm publish -r --provenance"
  }
}
```

## Validation

Check package before publish:

```bash
# What will be published
npm pack --dry-run

# Validate package.json
npm pkg get name version main types

# Check exports resolve
node -e "require('@scope/package')"
```
```

**Step 2: Commit**

```bash
git add skills/workflows/npm-publish/references/package-config.md
git commit -m "docs(npm-publish): add package configuration reference"
```

---

## Phase 7: Cleanup and Final Commit

### Task 7.1: Remove old setup.md if renamed

**Step 1: Check and clean up**

```bash
# Verify the rename worked
ls skills/workflows/npm-publish/references/

# Should show:
# changesets.md
# ci-workflows.md
# monorepo-setup.md
# package-config.md
# trusted-publishing.md
```

**Step 2: Update any references in SKILL.md**

Verify `skills/workflows/npm-publish/SKILL.md` references section matches actual files.

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore(npm-publish): complete monorepo documentation"
```

---

## Summary

### Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `SKILL.md` | Modified | Rewrote with monorepo workflow |
| `references/monorepo-setup.md` | Created | pnpm + Turborepo + Changesets setup |
| `references/changesets.md` | Created | Changeset creation and configuration |
| `references/trusted-publishing.md` | Created | NPM OIDC setup guide |
| `references/ci-workflows.md` | Created | GitHub Actions configuration |
| `references/package-config.md` | Created | package.json best practices |

### Key Patterns from devtools-mcp

1. **Changesets with pre-commit hook** - Enforces changeset creation
2. **Self-bootstrapping OIDC** - NPM_TOKEN fallback for new packages
3. **Turborepo task orchestration** - `^build` for dependency order
4. **Workspace protocol** - `workspace:*` for internal deps
5. **GitHub App for PRs** - Better than GITHUB_TOKEN for automation

### Testing

After implementation:

```bash
# Verify all reference files exist
ls skills/workflows/npm-publish/references/
# Should list 5 .md files

# Check SKILL.md references match
grep "references/" skills/workflows/npm-publish/SKILL.md
```
