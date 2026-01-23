---
name: npm-publish
description: Use when publishing npm packages to the npm registry
---

# npm Publish

## Overview

Publish npm packages with version management, quality gates, and automated CI/CD.

## Prerequisites

- **Quality gates passed:** All tests, lint, security must pass
- **npm account:** With publish access to package
- **NPM_TOKEN:** For CI/CD automation
- **package.json:** Properly configured

## The Rule

```
NO PUBLISH WITHOUT ALL QUALITY GATES PASSING
No "quick patch". No "just a README update".
Every publish goes through the full pipeline.
```

## Process

### 1. Verify Quality Gates

```bash
# All must pass:
npm test
npm run lint
npm audit --audit-level=high
```

### 2. Verify Package Configuration

```bash
# Check package.json
cat package.json | jq '.name, .version, .main, .files'

# Verify what will be published
npm pack --dry-run
```

### 3. Bump Version

```bash
# Patch (0.0.X) - bug fixes
npm version patch

# Minor (0.X.0) - new features, backwards compatible
npm version minor

# Major (X.0.0) - breaking changes
npm version major
```

This automatically:
- Updates package.json
- Creates git commit
- Creates git tag

### 4. Build (if needed)

```bash
# If package has build step
npm run build

# Verify dist files exist
ls dist/
```

### 5. Publish

```bash
# Publish to npm
npm publish

# For scoped packages (public)
npm publish --access public
```

### 6. Push Tags

```bash
git push origin main
git push origin --tags
```

### 7. Verify Publication

```bash
# Check npm registry
npm view your-package-name version

# Test installation
npm install your-package-name@latest
```

## CI/CD Automation

### GitHub Actions Workflow

Create `.github/workflows/publish.yml`:

```yaml
name: Publish

on:
  push:
    tags:
      - 'v*'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'
      
      - run: npm ci
      - run: npm test
      - run: npm run lint
      - run: npm audit --audit-level=high
      - run: npm run build --if-present
      
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### NPM Token Setup

1. Go to npmjs.com → Account → Access Tokens
2. Generate new token (Automation type)
3. Add as GitHub secret `NPM_TOKEN`

## Package Configuration

### Minimal package.json

```json
{
  "name": "your-package",
  "version": "1.0.0",
  "description": "Package description",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": [
    "dist"
  ],
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "lint": "eslint .",
    "prepublishOnly": "npm run build && npm test"
  },
  "keywords": ["keyword1", "keyword2"],
  "author": "Your Name",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/you/your-package"
  }
}
```

### Important Fields

| Field | Purpose |
|-------|---------|
| `main` | Entry point for CommonJS |
| `module` | Entry point for ESM |
| `types` | TypeScript definitions |
| `files` | What to include in package |
| `prepublishOnly` | Run before publish |

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Just a README update" | Still needs version bump and quality gates. |
| "Tests take too long" | Tests prevent broken publishes. Run them. |
| "It's a patch, no big deal" | Patches can break things. Full pipeline. |
| "I'll fix it in next version" | Users are affected now. Don't publish broken code. |

## Red Flags - STOP

- Publishing without running tests
- Skipping version bump
- Publishing from dirty working directory
- Ignoring npm audit warnings
- Using `--force` to bypass checks

**If you catch yourself doing any of these: STOP. Follow the process.**

## Verification

```bash
# Verify published version
npm view your-package version

# Verify package contents
npm pack your-package
tar -tzf your-package-*.tgz

# Test installation
cd /tmp && npm init -y && npm install your-package
```

## References

- `references/package-config.md` - Detailed package.json configuration
- `references/monorepo.md` - Publishing from monorepos
