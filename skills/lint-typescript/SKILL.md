---
name: lint-typescript
description: Use when checking code quality on TypeScript or JavaScript files before commit
---

# TypeScript/JavaScript Linting

## Overview

Run ESLint + Prettier on TypeScript/JavaScript files. All errors in modified files must be fixed.

## Tool Stack

| Tool | Purpose | Config File |
|------|---------|-------------|
| ESLint | Code quality rules | `.eslintrc.js` or `eslint.config.js` |
| Prettier | Code formatting | `.prettierrc` |
| @typescript-eslint | TypeScript-specific rules | Via ESLint config |

## The Rule

```
ALL LINT ERRORS IN MODIFIED FILES MUST BE FIXED
No "document for later". No "pre-existing issues".
You touch it, you own it.
```

## Process

### 1. Check Setup

```bash
# Verify ESLint configured
test -f .eslintrc.js || test -f .eslintrc.json || test -f eslint.config.js
```

**Not configured?** See `references/setup.md`

### 2. Get Changed Files

```bash
FILES=$(git diff --name-only main | grep -E '\.(ts|tsx|js|jsx)$' | tr '\n' ' ')
```

### 3. Run Lint

```bash
npx eslint $FILES
```

### 4. Run Format Check

```bash
npx prettier --check $FILES
```

### 5. Fix Issues

```bash
# Auto-fix what's possible
npx eslint --fix $FILES
npx prettier --write $FILES

# Manually fix remaining errors
```

### 6. Verify Clean

```bash
npx eslint $FILES
npx prettier --check $FILES
# Expected: no errors
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Pre-existing errors, not mine" | You modified the file. Fix ALL errors in it. |
| "Just formatting, not important" | Formatting prevents merge conflicts. Fix it. |
| "ESLint rule is wrong" | Disable inline with comment. Don't skip entirely. |
| "Will fix in follow-up PR" | No. Fix now. Lint is not negotiable. |
| "Only changed one line" | Doesn't matter. File is in your changeset. Own it. |

## Red Flags - STOP

- Running lint on entire codebase instead of changed files
- Disabling rules globally to make errors disappear
- Claiming "lint passed" without actually running it
- Using `// eslint-disable` without justification comment

**If you catch yourself doing any of these: STOP. Fix properly.**

## Inline Suppression (When Necessary)

```typescript
// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Legacy API requires any
function handleLegacyResponse(data: any): void {
  // ...
}
```

**Requirements for suppression:**
- Single line only (`eslint-disable-next-line`)
- Specific rule only (not `eslint-disable`)
- Justification comment explaining WHY

## Verification

```bash
npx eslint $(git diff --name-only main | grep -E '\.(ts|tsx|js|jsx)$')
# Expected: no output (clean)
```

## References

- `references/setup.md` - Initial ESLint + Prettier installation
- `references/config.md` - Recommended configuration
- `references/rules.md` - Common rules and how to handle them
