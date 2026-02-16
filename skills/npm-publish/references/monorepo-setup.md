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
