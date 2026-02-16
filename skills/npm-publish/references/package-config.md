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
