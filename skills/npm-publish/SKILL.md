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
