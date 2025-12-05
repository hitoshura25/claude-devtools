# Linting Check Skill

Run linter on code changes and fix all issues before marking work complete.

## Purpose

Ensure all code changes meet the project's style and quality standards. This is a **mandatory quality gate** - work is never complete with unfixed lint errors.

## Prerequisites

- Linter must be configured (use `linting-setup` skill if needed)
- Project has lint commands available

## Scope of Responsibility

**CRITICAL DISTINCTION: Modified Files vs Unchanged Files**

### Files You Modify

**When you touch a file for ANY reason, you own its code quality:**

- ✓ **Errors**: MUST fix all errors in modified files
- ✓ **Warnings**: MUST fix OR justify with inline comment
- ✓ **Style issues**: Auto-fix with formatter

**NO "unless documented" escape hatch for files you modify.**

**Example:**
```bash
# You modify src/api.ts to add endpoint
# Linter reports 5 pre-existing errors in same file
# YOU MUST FIX ALL 5 + ensure your new code is clean

git diff --name-only main
# src/api.ts ← You touched this, you own all issues

npm run lint -- src/api.ts
# Fix ALL errors, not just your new code
```

### Files You Don't Touch

**For files not in your changeset:**

- Errors: Not your responsibility (but create tracking issue if critical)
- Warnings: Not your responsibility
- Don't run lint --fix on entire codebase (changes too many files)

**How to verify:**
```bash
# Only lint files you actually changed
npm run lint -- $(git diff --name-only --diff-filter=ACMRTUXB main | grep '\.ts$')
```

### Why This Matters

**Incremental improvement philosophy:**
- Each PR should leave code cleaner than it found it
- "Boy Scout Rule": Leave the campground cleaner than you found it
- If everyone fixes issues in files they touch, codebase quality improves

**Bad practice:**
```
✗ "I added a function to utils.ts, but there are 10 pre-existing
   warnings. I'll just document them."
```

**Good practice:**
```
✓ "I'm touching utils.ts, so I'll fix the 10 warnings AND ensure
   my new function is lint-clean."
```

## Process

### 1. Run Linter

Execute the appropriate lint command for the project:

**TypeScript/JavaScript:**
```bash
npm run lint
# Or check specific files:
npm run lint -- src/auth.ts
```

**Python:**
```bash
# With Ruff (modern)
ruff check .

# With Pylint (traditional)
pylint your_package/

# Check specific file
ruff check src/parser.py
```

**Kotlin/Android:**
```bash
# ktlint
./gradlew ktlintCheck

# Detekt
./gradlew detekt

# Both
./gradlew ktlintCheck detekt
```

### 2. Review Lint Output

Understand what the linter is reporting:

**Example ESLint Output:**
```
src/auth.ts
  12:5   error    'token' is assigned a value but never used           @typescript-eslint/no-unused-vars
  23:10  warning  Unexpected console statement                         no-console
  45:1   error    Missing return type on function                      @typescript-eslint/explicit-function-return-type

✖ 3 problems (2 errors, 1 warning)
  1 error and 0 warnings potentially fixable with the `--fix` option
```

**Example Ruff Output:**
```
src/parser.py:12:5: F841 Local variable `data` is assigned to but never used
src/parser.py:23:10: E501 Line too long (105 > 88 characters)
src/parser.py:45:1: D103 Missing docstring in public function
Found 3 errors.
```

### 3. Auto-Fix What's Safe

Many linters can automatically fix certain issues:

**TypeScript/JavaScript:**
```bash
npm run lint:fix
# Or with direct eslint:
npx eslint . --ext .ts,.tsx --fix
```

**Python:**
```bash
# Ruff auto-fix
ruff check --fix .

# Or format with ruff
ruff format .
```

**Kotlin:**
```bash
# ktlint auto-format
./gradlew ktlintFormat
```

**What gets auto-fixed:**
- ✓ Formatting (spacing, indentation, line breaks)
- ✓ Import sorting
- ✓ Missing semicolons
- ✓ Quote style consistency
- ✓ Trailing whitespace

**What requires manual fixes:**
- ✗ Unused variables
- ✗ Missing return types
- ✗ Complex logic issues
- ✗ API misuse

### 4. Manually Fix Remaining Issues

For issues that can't be auto-fixed:

**Unused Variables:**
```typescript
// Before (error)
function processData(input: string, token: string) {
  return input.toUpperCase();
}

// Fix 1: Use the variable
function processData(input: string, token: string) {
  validateToken(token);
  return input.toUpperCase();
}

// Fix 2: Remove if not needed
function processData(input: string) {
  return input.toUpperCase();
}

// Fix 3: Prefix with _ if intentionally unused
function processData(input: string, _token: string) {
  return input.toUpperCase();
}
```

**Missing Return Types:**
```typescript
// Before (error)
function calculateTotal(items) {
  return items.reduce((sum, item) => sum + item.price, 0);
}

// Fix: Add types
function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}
```

**Line Too Long:**
```python
# Before (error - 120 chars)
user_data = fetch_user_from_database(user_id, include_profile=True, include_preferences=True, include_history=True)

# Fix: Break into multiple lines
user_data = fetch_user_from_database(
    user_id,
    include_profile=True,
    include_preferences=True,
    include_history=True
)
```

### 5. Handle Exceptions (Sparingly)

Sometimes you need to disable a rule, but ALWAYS document why:

**TypeScript Inline Disable:**
```typescript
// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Legacy API requires any type
function handleLegacyResponse(data: any): void {
  // ...
}
```

**Python Inline Disable:**
```python
# ruff: noqa: E501 -- URL is long and cannot be broken
LEGACY_API_URL = "https://api.example.com/v1/very/long/path/that/cannot/be/shortened"
```

**Kotlin Suppress:**
```kotlin
@Suppress("MagicNumber") // Port numbers are inherently magic
const val DEFAULT_PORT = 8080
```

**Rules for Exceptions:**
- ✓ Always include a comment explaining WHY
- ✓ Be as specific as possible (disable one rule, not all)
- ✓ Use inline disables, not file-level or project-level
- ✓ Consider if there's a better way to fix the issue
- ✗ Never disable rules just because you don't want to fix them

### 6. Re-Run Linter

After fixing issues, run linter again to confirm clean:

```bash
npm run lint        # TypeScript
ruff check .        # Python
./gradlew ktlintCheck  # Kotlin
```

Expected output:
```
✓ No linting errors found
```

### 7. Check Formatting

If project uses a formatter (Prettier, Black, ktlint format):

**TypeScript/JavaScript with Prettier:**
```bash
npm run format:check
# If issues found:
npm run format
```

**Python with Ruff:**
```bash
ruff format --check .
# If issues found:
ruff format .
```

**Kotlin with ktlint:**
```bash
./gradlew ktlintCheck
# If issues found:
./gradlew ktlintFormat
```

## Common Lint Issues and Fixes

### Unused Imports

**Before:**
```typescript
import { useState, useEffect, useMemo } from 'react';

function MyComponent() {
  const [count, setCount] = useState(0);
  return <div>{count}</div>;
}
```

**Fix: Remove unused imports**
```typescript
import { useState } from 'react';

function MyComponent() {
  const [count, setCount] = useState(0);
  return <div>{count}</div>;
}
```

### Inconsistent Naming

**Before:**
```python
def Calculate_Total(item_list):
    total_sum = 0
    for Item in item_list:
        total_sum += Item.price
    return total_sum
```

**Fix: Follow conventions (snake_case for Python)**
```python
def calculate_total(item_list):
    total_sum = 0
    for item in item_list:
        total_sum += item.price
    return total_sum
```

### Missing Documentation

**Before:**
```typescript
export function processPayment(amount: number, userId: string) {
  // ...
}
```

**Fix: Add JSDoc**
```typescript
/**
 * Process a payment for a user.
 * @param amount - Payment amount in cents
 * @param userId - User's unique identifier
 * @returns Payment confirmation ID
 */
export function processPayment(amount: number, userId: string): string {
  // ...
}
```

### Complexity Issues

**Before (too complex):**
```typescript
function validateUser(user) {
  if (user) {
    if (user.email) {
      if (user.email.includes('@')) {
        if (user.password) {
          if (user.password.length > 8) {
            return true;
          }
        }
      }
    }
  }
  return false;
}
```

**Fix: Simplify with early returns**
```typescript
function validateUser(user: User): boolean {
  if (!user) return false;
  if (!user.email || !user.email.includes('@')) return false;
  if (!user.password || user.password.length <= 8) return false;
  return true;
}
```

## Lint vs Format

Understand the difference:

**Linting (code quality):**
- Finds bugs and code smells
- Enforces best practices
- Checks for unused code
- Examples: ESLint, Pylint, Ruff, Detekt

**Formatting (code style):**
- Consistent spacing and indentation
- Line breaks and wrapping
- Quote style
- Examples: Prettier, Black, ktlint format

**Both are important, but different:**
- Linting catches logic issues
- Formatting ensures visual consistency

## Output Confirmation

Before proceeding to next quality gate:

```
✓ Linter executed successfully
✓ No errors in modified files (MANDATORY)
✓ Warnings in modified files: fixed OR justified with inline comments
✓ Code formatting is consistent in modified files
✓ Pre-existing errors in other files: tracked but not blocking
✓ Scope clearly documented (which files touched)
```

## Integration with CI/CD

Lint checks should also run in CI to catch issues:

**GitHub Actions Example:**
```yaml
- name: Run linter
  run: npm run lint
  
- name: Check formatting
  run: npm run format:check
```

## CRITICAL RULE

**NEVER** claim work is complete with unfixed lint errors IN FILES YOU MODIFY.

**For files in your changeset:**
1. Auto-fix what you can (`npm run lint:fix`)
2. Manually fix remaining errors (ALL of them)
3. Fix warnings OR add inline justification (e.g., `// eslint-disable-next-line no-console -- Debug logging required`)
4. Re-run until clean

**For files outside your changeset:**
1. Don't auto-fix (would change too many files)
2. Create tracking issues if there are widespread problems
3. Don't block on these

**The "unless documented" escape hatch does NOT apply to files you modify.**

**How to verify your scope:**
```bash
# Your changed files
git diff --name-only main

# Lint only those
npm run lint -- $(git diff --name-only main | grep '\.ts$')

# MUST be clean for these files
```

But **always** end with a clean lint report for files you modify.

## Performance Tips

**Lint only changed files (for large codebases):**

**Git diff approach:**
```bash
# Get changed files
git diff --name-only --diff-filter=ACMRTUXB main | grep '\.ts$'

# Lint only those
npm run lint -- $(git diff --name-only --diff-filter=ACMRTUXB main | grep '\.ts$')
```

**Ruff with git:**
```bash
ruff check $(git diff --name-only --diff-filter=ACMRTUXB main | grep '\.py$')
```

This is especially useful for:
- Large legacy codebases
- Pre-commit hooks
- Faster CI feedback

## Next Steps

After linting passes:
- Proceed to `security-check` skill
- Final step before marking work complete
