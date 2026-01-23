---
name: lint-python
description: Use when checking code quality on Python files before commit
---

# Python Linting

## Overview

Run Ruff on Python files for linting and formatting. All errors in modified files must be fixed.

## Tool Stack

| Tool | Purpose | Config File |
|------|---------|-------------|
| Ruff | Linting + formatting (replaces flake8, black, isort) | `ruff.toml` or `pyproject.toml` |

**Why Ruff?** 10-100x faster than alternatives, replaces multiple tools, excellent defaults.

## The Rule

```
ALL LINT ERRORS IN MODIFIED FILES MUST BE FIXED
No "document for later". No "pre-existing issues".
You touch it, you own it.
```

## Process

### 1. Check Setup

```bash
# Verify Ruff installed
ruff --version
```

**Not installed?** See `references/setup.md`

### 2. Get Changed Files

```bash
FILES=$(git diff --name-only main | grep '\.py$' | tr '\n' ' ')
```

### 3. Run Lint Check

```bash
ruff check $FILES
```

### 4. Run Format Check

```bash
ruff format --check $FILES
```

### 5. Fix Issues

```bash
# Auto-fix what's possible
ruff check --fix $FILES
ruff format $FILES

# Manually fix remaining errors
```

### 6. Verify Clean

```bash
ruff check $FILES
ruff format --check $FILES
# Expected: no errors
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Pre-existing errors, not mine" | You modified the file. Fix ALL errors in it. |
| "Just formatting, not important" | Formatting prevents merge conflicts. Fix it. |
| "Ruff rule is too strict" | Disable inline with comment. Don't skip entirely. |
| "Will fix in follow-up PR" | No. Fix now. Lint is not negotiable. |
| "Type hints are optional" | Not in this codebase. Add them. |

## Red Flags - STOP

- Running ruff on entire codebase instead of changed files
- Adding `# noqa` without justification comment
- Disabling rules in `pyproject.toml` to hide errors
- Claiming "lint passed" without running it

**If you catch yourself doing any of these: STOP. Fix properly.**

## Inline Suppression (When Necessary)

```python
# ruff: noqa: E501 - URL cannot be shortened
LEGACY_API_URL = "https://api.example.com/v1/very/long/path/that/cannot/be/shortened"
```

**Requirements for suppression:**
- Specific rule code (e.g., `E501`, not just `noqa`)
- Justification comment explaining WHY
- Single line only when possible

## Verification

```bash
ruff check $(git diff --name-only main | grep '\.py$')
# Expected: All checks passed!
```

## References

- `references/setup.md` - Ruff installation and configuration
- `references/rules.md` - Common rules and how to handle them
