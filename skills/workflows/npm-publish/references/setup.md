# npm Publishing Setup

## npm Account

### Create Account

1. Go to https://www.npmjs.com/signup
2. Verify email
3. Enable 2FA (required for publishing)

### Login Locally

```bash
npm login
# Enter username, password, email, OTP
```

### Verify Login

```bash
npm whoami
```

## NPM_TOKEN for CI

### Generate Token

1. npmjs.com → Account → Access Tokens
2. Generate New Token → Automation
3. Copy token (shown only once)

### Store in GitHub

1. Repository → Settings → Secrets → Actions
2. New repository secret
3. Name: `NPM_TOKEN`
4. Value: paste token

## package.json Setup

### Required Fields

```json
{
  "name": "your-package",
  "version": "1.0.0",
  "description": "What it does",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": [
    "dist"
  ],
  "keywords": ["keyword1", "keyword2"],
  "author": "Your Name <email@example.com>",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/user/repo.git"
  },
  "bugs": {
    "url": "https://github.com/user/repo/issues"
  },
  "homepage": "https://github.com/user/repo#readme"
}
```

### Scoped Packages

```json
{
  "name": "@yourorg/package-name",
  "publishConfig": {
    "access": "public"
  }
}
```

### Scripts

```json
{
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "lint": "eslint src/",
    "prepublishOnly": "npm run build && npm test && npm run lint"
  }
}
```

## Version Management

### Semantic Versioning

- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Version Commands

```bash
# Bump and commit
npm version patch
npm version minor
npm version major

# Prerelease
npm version prerelease --preid=alpha  # 1.0.0-alpha.0
npm version prerelease --preid=beta   # 1.0.0-beta.0
npm version prerelease --preid=rc     # 1.0.0-rc.0

# Without git commit
npm version patch --no-git-tag-version
```

## Publishing

### First Publish

```bash
# Verify package contents
npm pack --dry-run

# Publish
npm publish

# For scoped packages
npm publish --access public
```

### Subsequent Publishes

```bash
npm version patch
npm publish
git push origin main --tags
```

### Prerelease Publish

```bash
npm version prerelease --preid=beta
npm publish --tag beta
```

Users install with:
```bash
npm install your-package@beta
```

## Unpublish Policy

npm has restrictions:
- Can unpublish within 72 hours
- Cannot unpublish if others depend on it
- Use `npm deprecate` instead

```bash
# Deprecate a version
npm deprecate your-package@1.0.0 "Critical bug, use 1.0.1"

# Unpublish (if allowed)
npm unpublish your-package@1.0.0
```

## Troubleshooting

### "You must be logged in"

```bash
npm login
```

### "Permission denied"

Check you have publish rights:
```bash
npm access ls-packages
```

### "Cannot publish over existing version"

Version already exists. Bump version:
```bash
npm version patch
```

### "Package name too similar"

Name conflicts with existing package. Choose different name.
