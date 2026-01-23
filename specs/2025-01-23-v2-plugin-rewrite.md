# DevTools Plugin v2 Rewrite - Implementation Spec

> **For Claude Code:** Use `superpowers:executing-plans` to implement this spec task-by-task. Each task is atomic and should take 2-5 minutes.

**Goal:** Create a Claude Code plugin providing quality gates (lint, security, AI review) and deployment workflows (Android, npm, PyPI) that complement Superpowers methodology skills.

**Architecture:** 
- Plugin structure follows Claude Code plugin spec (`.claude-plugin/plugin.json`)
- Skills follow Superpowers patterns: <300 lines, anti-rationalization tables, red flags sections
- Commands wrap skills for user-invoked workflows
- Session-start hook bootstraps context

**Tech Stack:**
- ESLint + Prettier (TypeScript/JS)
- Ruff (Python)
- ktlint (Kotlin)
- Semgrep + OSV-Scanner (Security)
- Ollama with OLMo/Gemma (AI Review)
- Fastlane (Android deployment)

**Reference Repositories:**
- Superpowers patterns: `~/superpowers/skills/` (especially `test-driven-development`, `writing-skills`)
- Plugin structure: `~/superpowers-developing-for-claude-code/skills/developing-claude-code-plugins/references/plugin-structure.md`
- Official docs: `~/superpowers-developing-for-claude-code/skills/working-with-claude-code/references/skills.md`

---

## Phase 1: Plugin Foundation

### Task 1.1: Create Plugin Manifest

**Files:**
- Create: `.claude-plugin/plugin.json`

**Step 1: Create directory and file**

```bash
mkdir -p .claude-plugin
```

**Step 2: Write plugin.json**

```json
{
  "name": "devtools",
  "version": "2.0.0",
  "description": "Quality gates and deployment workflows for AI-driven development",
  "author": {
    "name": "Vinayak Menon"
  },
  "homepage": "https://github.com/anthropics/claude-devtools",
  "license": "MIT",
  "keywords": [
    "quality-gates",
    "linting",
    "security",
    "android",
    "deployment",
    "ci-cd"
  ]
}
```

**Step 3: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "chore: add plugin manifest"
```

---

### Task 1.2: Create Development Marketplace

**Files:**
- Create: `.claude-plugin/marketplace.json`

**Step 1: Write marketplace.json**

```json
{
  "name": "devtools-dev",
  "description": "Development marketplace for devtools plugin",
  "owner": {
    "name": "Vinayak Menon"
  },
  "plugins": [
    {
      "name": "devtools",
      "description": "Quality gates and deployment workflows",
      "version": "2.0.0",
      "source": "./"
    }
  ]
}
```

**Step 2: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore: add development marketplace"
```

---

### Task 1.3: Create Session Bootstrap Hook

**Files:**
- Create: `hooks/hooks.json`
- Create: `hooks/session-init.md`

**Step 1: Create hooks directory**

```bash
mkdir -p hooks
```

**Step 2: Write hooks.json**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cat \"${CLAUDE_PLUGIN_ROOT}/hooks/session-init.md\""
          }
        ]
      }
    ]
  }
}
```

**Step 3: Write session-init.md**

```markdown
<DEVTOOLS_CONTEXT>
You have access to the devtools plugin for quality gates and deployment workflows.

**Quality Gates (use before marking work complete):**
- `devtools:lint-typescript` / `devtools:lint-python` / `devtools:lint-kotlin`
- `devtools:security-scanning`
- `devtools:ai-code-review` (requires Ollama)

**Deployment Workflows:**
- `devtools:android-release`
- `devtools:npm-publish`
- `devtools:pypi-publish`

**For TDD, planning, and execution methodology:** Use `superpowers` skills.

Quality gates are NOT optional. All must pass before work is complete.
</DEVTOOLS_CONTEXT>
```

**Step 4: Commit**

```bash
git add hooks/
git commit -m "feat: add session-start bootstrap hook"
```

---

### Task 1.4: Create Directory Structure

**Files:**
- Create: directory tree for skills and commands

**Step 1: Create all directories**

```bash
# Commands
mkdir -p commands

# Quality gate skills
mkdir -p skills/quality-gates/lint-typescript/references
mkdir -p skills/quality-gates/lint-python/references
mkdir -p skills/quality-gates/lint-kotlin/references
mkdir -p skills/quality-gates/security-scanning/references
mkdir -p skills/quality-gates/ai-code-review/references

# Workflow skills
mkdir -p skills/workflows/android-release/references
mkdir -p skills/workflows/npm-publish/references
mkdir -p skills/workflows/pypi-publish/references

# Standalone skills
mkdir -p skills/version-management/references
```

**Step 2: Create .gitkeep files to preserve empty directories**

```bash
touch commands/.gitkeep
find skills -type d -empty -exec touch {}/.gitkeep \;
```

**Step 3: Commit**

```bash
git add .
git commit -m "chore: create plugin directory structure"
```

---

## Phase 2: Quality Gate Skills

### Task 2.1: Create lint-typescript Skill

**Files:**
- Create: `skills/quality-gates/lint-typescript/SKILL.md`
- Create: `skills/quality-gates/lint-typescript/references/setup.md`
- Create: `skills/quality-gates/lint-typescript/references/config.md`

**Step 1: Write SKILL.md**

Write to `skills/quality-gates/lint-typescript/SKILL.md`:

```markdown
---
name: lint-typescript
description: Use when checking code quality on TypeScript or JavaScript files before commit
---

# TypeScript/JavaScript Linting

## Overview

Run ESLint + Prettier on TypeScript/JavaScript files. All errors in modified files must be fixed.

## Tool Stack

| Tool | Purpose | Config |
|------|---------|--------|
| ESLint | Code quality | `.eslintrc.js` or `eslint.config.js` |
| Prettier | Formatting | `.prettierrc` |
| @typescript-eslint | TS-specific rules | Via ESLint |

## The Rule

```
ALL LINT ERRORS IN MODIFIED FILES MUST BE FIXED
No "document for later". No "pre-existing issues".
You touch it, you own it.
```

## Process

### 1. Check Setup

```bash
test -f .eslintrc.js || test -f .eslintrc.json || test -f eslint.config.js || test -f .eslintrc.cjs
```

**Not configured?** See `references/setup.md`

### 2. Get Changed Files

```bash
FILES=$(git diff --name-only main | grep -E '\.(ts|tsx|js|jsx)$' | tr '\n' ' ')
```

### 3. Run Lint

```bash
npx eslint $FILES
npx prettier --check $FILES
```

### 4. Fix Issues

```bash
# Auto-fix
npx eslint --fix $FILES
npx prettier --write $FILES

# Manually fix remaining
```

### 5. Verify Clean

```bash
npx eslint $FILES
# Expected: no output (clean)
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Pre-existing errors, not mine" | You modified the file. Fix all errors in it. |
| "Just formatting, not important" | Formatting prevents merge conflicts. Fix it. |
| "ESLint rule is wrong" | Disable with inline comment + justification. Don't skip. |
| "Will fix in follow-up PR" | No. Fix now. Quality gates are not negotiable. |

## Red Flags - STOP

- Running lint on entire codebase instead of changed files
- Disabling rules globally to make errors disappear
- Claiming "lint passed" without actually running it
- Skipping because "it's just a small change"

**If you catch yourself doing any of these: STOP. Follow the process.**

## Verification

```bash
npx eslint $(git diff --name-only main | grep -E '\.(ts|tsx|js|jsx)$')
# Expected output: (empty - no errors)
```

## References

- `references/setup.md` - Initial ESLint/Prettier setup
- `references/config.md` - Recommended configuration
```

**Step 2: Write references/setup.md**

Write to `skills/quality-gates/lint-typescript/references/setup.md`:

```markdown
# TypeScript Lint Setup

## Installation

```bash
npm install --save-dev \
  eslint \
  @typescript-eslint/parser \
  @typescript-eslint/eslint-plugin \
  prettier \
  eslint-config-prettier
```

## Quick Setup

```bash
npx eslint --init
```

Or manually create files below.

## Manual Configuration

### `.eslintrc.js`

```javascript
module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'prettier'  // Must be last
  ],
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module',
  },
  rules: {
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/explicit-function-return-type': 'warn',
    'no-console': 'warn',
  },
  ignorePatterns: ['node_modules/', 'dist/', 'build/'],
};
```

### `.prettierrc`

```json
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2
}
```

### `package.json` scripts

```json
{
  "scripts": {
    "lint": "eslint . --ext .ts,.tsx,.js,.jsx",
    "lint:fix": "eslint . --ext .ts,.tsx,.js,.jsx --fix",
    "format": "prettier --write \"src/**/*.{ts,tsx,js,jsx}\"",
    "format:check": "prettier --check \"src/**/*.{ts,tsx,js,jsx}\""
  }
}
```

## Verification

```bash
npm run lint
# Should complete (may show warnings for existing code)
```
```

**Step 3: Write references/config.md**

Write to `skills/quality-gates/lint-typescript/references/config.md`:

```markdown
# ESLint Configuration Reference

## Recommended Rules

### Error Level (Must Fix)

```javascript
rules: {
  '@typescript-eslint/no-unused-vars': 'error',
  '@typescript-eslint/no-explicit-any': 'error',
  'no-undef': 'error',
}
```

### Warning Level (Should Fix)

```javascript
rules: {
  '@typescript-eslint/explicit-function-return-type': 'warn',
  'no-console': 'warn',
  'prefer-const': 'warn',
}
```

## Inline Disabling

When you must disable a rule, always add justification:

```typescript
// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Legacy API requires any
function handleLegacyResponse(data: any): void {
  // ...
}
```

**Never disable without justification.**

## React Projects

Add React plugin:

```bash
npm install --save-dev eslint-plugin-react eslint-plugin-react-hooks
```

```javascript
extends: [
  'eslint:recommended',
  'plugin:@typescript-eslint/recommended',
  'plugin:react/recommended',
  'plugin:react-hooks/recommended',
  'prettier'
],
settings: {
  react: {
    version: 'detect',
  },
},
```
```

**Step 4: Remove .gitkeep**

```bash
rm -f skills/quality-gates/lint-typescript/.gitkeep
rm -f skills/quality-gates/lint-typescript/references/.gitkeep
```

**Step 5: Commit**

```bash
git add skills/quality-gates/lint-typescript/
git commit -m "feat: add lint-typescript skill"
```

---

### Task 2.2: Create lint-python Skill

**Files:**
- Create: `skills/quality-gates/lint-python/SKILL.md`
- Create: `skills/quality-gates/lint-python/references/setup.md`

**Step 1: Write SKILL.md**

Write to `skills/quality-gates/lint-python/SKILL.md`:

```markdown
---
name: lint-python
description: Use when checking code quality on Python files before commit
---

# Python Linting

## Overview

Run Ruff on Python files. All errors in modified files must be fixed.

## Tool Stack

| Tool | Purpose | Config |
|------|---------|--------|
| Ruff | Linting + Formatting | `ruff.toml` or `pyproject.toml` |

## The Rule

```
ALL LINT ERRORS IN MODIFIED FILES MUST BE FIXED
No "document for later". No "pre-existing issues".
You touch it, you own it.
```

## Process

### 1. Check Setup

```bash
test -f ruff.toml || grep -q "\[tool.ruff\]" pyproject.toml 2>/dev/null
```

**Not configured?** See `references/setup.md`

### 2. Get Changed Files

```bash
FILES=$(git diff --name-only main | grep '\.py$' | tr '\n' ' ')
```

### 3. Run Lint

```bash
ruff check $FILES
ruff format --check $FILES
```

### 4. Fix Issues

```bash
# Auto-fix
ruff check --fix $FILES
ruff format $FILES

# Manually fix remaining
```

### 5. Verify Clean

```bash
ruff check $FILES
# Expected: All checks passed!
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Pre-existing errors, not mine" | You modified the file. Fix all errors in it. |
| "Ruff rule is too strict" | Disable with inline comment + justification. Don't skip. |
| "Will fix in follow-up PR" | No. Fix now. Quality gates are not negotiable. |
| "Black/isort conflicts" | Ruff replaces both. Use Ruff only. |

## Red Flags - STOP

- Running lint on entire codebase instead of changed files
- Adding `# noqa` without justification
- Claiming "lint passed" without actually running it
- Using multiple conflicting formatters

**If you catch yourself doing any of these: STOP. Follow the process.**

## Verification

```bash
ruff check $(git diff --name-only main | grep '\.py$')
# Expected: All checks passed!
```

## References

- `references/setup.md` - Initial Ruff setup
```

**Step 2: Write references/setup.md**

Write to `skills/quality-gates/lint-python/references/setup.md`:

```markdown
# Python Lint Setup (Ruff)

## Installation

```bash
pip install ruff
```

Or with pipx (recommended for CLI tools):

```bash
pipx install ruff
```

## Configuration

### `ruff.toml` (Standalone)

```toml
line-length = 88
indent-width = 4
target-version = "py311"

[lint]
select = [
  "E",   # pycodestyle errors
  "F",   # pyflakes
  "W",   # pycodestyle warnings
  "I",   # isort
  "N",   # pep8-naming
  "UP",  # pyupgrade
  "B",   # flake8-bugbear
  "A",   # flake8-builtins
  "C4",  # flake8-comprehensions
  "T20", # flake8-print
]
ignore = []
fixable = ["ALL"]

[lint.per-file-ignores]
"tests/*" = ["S101"]  # Allow assert in tests

[format]
quote-style = "double"
indent-style = "space"
```

### `pyproject.toml` (If using pyproject)

```toml
[tool.ruff]
line-length = 88
indent-width = 4
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "N", "UP", "B", "A", "C4", "T20"]
ignore = []
fixable = ["ALL"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
```

## Verification

```bash
ruff check .
ruff format --check .
# Should complete without errors
```

## Migration from Black/isort

Ruff replaces both Black and isort. Remove them:

```bash
pip uninstall black isort
# Remove [tool.black] and [tool.isort] from pyproject.toml
```
```

**Step 3: Remove .gitkeep and commit**

```bash
rm -f skills/quality-gates/lint-python/.gitkeep
rm -f skills/quality-gates/lint-python/references/.gitkeep
git add skills/quality-gates/lint-python/
git commit -m "feat: add lint-python skill"
```

---

### Task 2.3: Create lint-kotlin Skill

**Files:**
- Create: `skills/quality-gates/lint-kotlin/SKILL.md`
- Create: `skills/quality-gates/lint-kotlin/references/setup.md`

**Step 1: Write SKILL.md**

Write to `skills/quality-gates/lint-kotlin/SKILL.md`:

```markdown
---
name: lint-kotlin
description: Use when checking code quality on Kotlin files before commit
---

# Kotlin Linting

## Overview

Run ktlint on Kotlin files. All errors in modified files must be fixed.

## Tool Stack

| Tool | Purpose | Config |
|------|---------|--------|
| ktlint | Linting + Formatting | `.editorconfig` |
| Detekt | Static analysis (optional) | `detekt.yml` |

## The Rule

```
ALL LINT ERRORS IN MODIFIED FILES MUST BE FIXED
No "document for later". No "pre-existing issues".
You touch it, you own it.
```

## Process

### 1. Check Setup

```bash
./gradlew tasks | grep -q ktlint
```

**Not configured?** See `references/setup.md`

### 2. Run Lint

```bash
./gradlew ktlintCheck
```

### 3. Fix Issues

```bash
# Auto-fix
./gradlew ktlintFormat

# Manually fix remaining
```

### 4. Verify Clean

```bash
./gradlew ktlintCheck
# Expected: BUILD SUCCESSFUL
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Pre-existing errors, not mine" | You modified the file. Fix all errors in it. |
| "ktlint rule is too strict" | Disable in .editorconfig with justification. Don't skip. |
| "Gradle is slow" | Run on changed files only. Still required. |
| "Android Studio formats differently" | Configure AS to use ktlint. One formatter. |

## Red Flags - STOP

- Skipping ktlint because "Gradle takes too long"
- Using Android Studio formatter instead of ktlint
- Adding @Suppress without justification
- Claiming "lint passed" without running Gradle task

**If you catch yourself doing any of these: STOP. Follow the process.**

## Verification

```bash
./gradlew ktlintCheck
# Expected: BUILD SUCCESSFUL
```

## References

- `references/setup.md` - Initial ktlint setup
```

**Step 2: Write references/setup.md**

Write to `skills/quality-gates/lint-kotlin/references/setup.md`:

```markdown
# Kotlin Lint Setup (ktlint)

## Gradle Plugin Setup

### `build.gradle.kts` (Project level or app level)

```kotlin
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
}

ktlint {
    version.set("1.1.1")
    android.set(true)
    outputToConsole.set(true)
    ignoreFailures.set(false)
    enableExperimentalRules.set(false)
    filter {
        exclude("**/generated/**")
        include("**/kotlin/**")
    }
}
```

### `.editorconfig`

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.{kt,kts}]
indent_style = space
indent_size = 4
max_line_length = 120
ktlint_standard_no-wildcard-imports = disabled
```

## Available Tasks

```bash
# Check for issues
./gradlew ktlintCheck

# Auto-fix issues
./gradlew ktlintFormat

# Check specific source set
./gradlew ktlintMainSourceSetCheck
./gradlew ktlintTestSourceSetCheck
```

## Detekt (Optional - Static Analysis)

For deeper static analysis, add Detekt:

```kotlin
plugins {
    id("io.gitlab.arturbosch.detekt") version "1.23.4"
}

detekt {
    buildUponDefaultConfig = true
    config.setFrom(files("$projectDir/config/detekt/detekt.yml"))
}
```

## Verification

```bash
./gradlew ktlintCheck
# Should show BUILD SUCCESSFUL
```
```

**Step 3: Remove .gitkeep and commit**

```bash
rm -f skills/quality-gates/lint-kotlin/.gitkeep
rm -f skills/quality-gates/lint-kotlin/references/.gitkeep
git add skills/quality-gates/lint-kotlin/
git commit -m "feat: add lint-kotlin skill"
```

---

### Task 2.4: Create security-scanning Skill

**Files:**
- Create: `skills/quality-gates/security-scanning/SKILL.md`
- Create: `skills/quality-gates/security-scanning/references/setup.md`
- Create: `skills/quality-gates/security-scanning/references/severity-guide.md`

**Step 1: Write SKILL.md**

Write to `skills/quality-gates/security-scanning/SKILL.md`:

```markdown
---
name: security-scanning
description: Use when checking for security vulnerabilities before commit or merge
---

# Security Scanning

## Overview

Run Semgrep (SAST) + OSV-Scanner (dependencies). Critical/High findings block merge.

## Tool Stack

| Tool | Purpose | Scope |
|------|---------|-------|
| Semgrep | Static analysis | Code vulnerabilities |
| OSV-Scanner | Dependency check | Known CVEs |
| npm audit | JS package audit | npm projects |
| pip-audit | Python package audit | Python projects |

## The Rule

```
CRITICAL AND HIGH SEVERITY FINDINGS MUST BE FIXED
No exceptions. No "document for later".
Security vulnerabilities are not negotiable.
```

## Process

### 1. Run Semgrep (All Languages)

```bash
semgrep --config=auto --error --severity=ERROR .
```

**Flags:**
- `--config=auto` - Recommended rules for detected languages
- `--error` - Exit non-zero on findings
- `--severity=ERROR` - Critical/high only

### 2. Run OSV-Scanner

```bash
osv-scanner --recursive .
```

### 3. Run Language-Specific Audit

**JavaScript/TypeScript:**
```bash
npm audit --audit-level=high
```

**Python:**
```bash
pip-audit
```

### 4. Address Findings

| Severity | Action |
|----------|--------|
| CRITICAL | Fix immediately. No exceptions. |
| HIGH | Fix immediately. No exceptions. |
| MEDIUM | Fix OR create tracking issue with justification |
| LOW | Document if deferring |

### 5. Verify Clean

```bash
semgrep --config=auto --error --severity=ERROR .
osv-scanner --recursive .
# Both exit 0
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "False positive" | Add inline suppression with justification. Don't skip scan. |
| "Only in dev dependencies" | Still a vulnerability. Still needs assessment. |
| "No exploit available" | Exploits appear without warning. Fix now. |
| "I didn't introduce it" | You're modifying the codebase. You own its security. |
| "Will fix in security sprint" | Security debt compounds. Fix in this PR. |

## Red Flags - STOP

- Skipping scan because "it's just a small change"
- Suppressing findings without inline justification
- Claiming "scan passed" without running it
- Ignoring HIGH findings because "no time"

**If you catch yourself doing any of these: STOP. Follow the process.**

## Verification

```bash
semgrep --config=auto . 2>&1 | grep -c "findings" || echo "0 findings"
osv-scanner --recursive . 2>&1 | grep -c "vulnerability" || echo "0 vulnerabilities"
```

## References

- `references/setup.md` - Tool installation
- `references/severity-guide.md` - How to triage findings
```

**Step 2: Write references/setup.md**

Write to `skills/quality-gates/security-scanning/references/setup.md`:

```markdown
# Security Scanning Setup

## Semgrep Installation

```bash
# Via pip (recommended)
pip install semgrep

# Via Homebrew (macOS)
brew install semgrep

# Verify
semgrep --version
```

## OSV-Scanner Installation

```bash
# Via Homebrew (macOS)
brew install osv-scanner

# Via Go
go install github.com/google/osv-scanner/cmd/osv-scanner@latest

# Verify
osv-scanner --version
```

## Language-Specific Tools

### JavaScript/TypeScript

```bash
# npm audit is built-in
npm audit
```

### Python

```bash
pip install pip-audit
pip-audit
```

## Quick Scan Script

Create `scripts/security-scan.sh`:

```bash
#!/bin/bash
set -e

echo "=== Security Scan ==="

echo "1. Semgrep (SAST)..."
semgrep --config=auto --error .

echo "2. OSV-Scanner (Dependencies)..."
osv-scanner --recursive .

echo "3. Language-specific audit..."
if [ -f package-lock.json ]; then
    npm audit --audit-level=high
fi
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
    pip-audit 2>/dev/null || echo "pip-audit not installed"
fi

echo "=== All security checks passed ==="
```

```bash
chmod +x scripts/security-scan.sh
```

## CI Integration

### GitHub Actions

```yaml
- name: Run Semgrep
  uses: returntocorp/semgrep-action@v1
  with:
    config: auto

- name: Run OSV-Scanner
  uses: google/osv-scanner-action@v1
  with:
    scan-args: --recursive .
```
```

**Step 3: Write references/severity-guide.md**

Write to `skills/quality-gates/security-scanning/references/severity-guide.md`:

```markdown
# Security Severity Guide

## Severity Levels

### CRITICAL - Fix Immediately

- Remote Code Execution (RCE)
- SQL Injection with data access
- Authentication bypass
- Hardcoded production secrets/credentials
- Exposed private keys

**Action:** Stop all other work. Fix now.

### HIGH - Fix Before Merge

- SQL Injection (limited scope)
- XSS (Cross-Site Scripting)
- Path traversal
- Insecure deserialization
- High-severity CVEs with known exploits

**Action:** Fix in current PR. No exceptions.

### MEDIUM - Fix or Document

- Weak cryptography
- Information disclosure
- CSRF without sensitive actions
- Moderate CVEs

**Action:** Fix if possible. If deferring, create tracking issue with:
- Finding ID/CVE
- Risk assessment
- Mitigation plan
- Review date

### LOW - Document If Deferring

- Best practice violations
- Low-risk dependencies
- Informational findings

**Action:** Fix if trivial. Otherwise document and move on.

## Suppression Format

When suppressing a finding, always include justification:

### Semgrep

```python
# nosemgrep: python.lang.security.audit.dangerous-spawn-process
# Justification: Input is validated against allowlist, not user-controlled
subprocess.run(validated_command)
```

### OSV-Scanner

Create `osv-scanner.toml`:

```toml
[[IgnoredVulns]]
id = "CVE-2023-12345"
reason = "Only affects Windows, we deploy on Linux only"
```

## Tracking Issue Template

```markdown
## Security Finding: [Title]

**Severity:** [MEDIUM/LOW]
**ID:** [CVE/Finding ID]
**Package:** [if dependency]
**File:** [if code]

### Risk Assessment
[Why this is acceptable risk]

### Mitigation
[What reduces the risk]

### Resolution Plan
[When/how this will be fixed]

### Review Date
[When to reassess]
```
```

**Step 4: Remove .gitkeep and commit**

```bash
rm -f skills/quality-gates/security-scanning/.gitkeep
rm -f skills/quality-gates/security-scanning/references/.gitkeep
git add skills/quality-gates/security-scanning/
git commit -m "feat: add security-scanning skill"
```

---

### Task 2.5: Create ai-code-review Skill

**Files:**
- Create: `skills/quality-gates/ai-code-review/SKILL.md`
- Create: `skills/quality-gates/ai-code-review/references/ollama-setup.md`
- Create: `skills/quality-gates/ai-code-review/references/prompts.md`

**Step 1: Write SKILL.md**

Write to `skills/quality-gates/ai-code-review/SKILL.md`:

```markdown
---
name: ai-code-review
description: Use when code changes are ready for AI review via local Ollama models after tests and lint pass
---

# AI Code Review

## Overview

Run local AI models via Ollama to review changes for spec compliance and code quality. Complements (not replaces) tests and lint.

## Prerequisites

- Ollama running: `ollama serve`
- Model available: `ollama pull llama3.2` or `ollama pull gemma2`

## The Rule

```
AI REVIEW IS ADDITIONAL VERIFICATION, NOT A SHORTCUT
Tests and lint must pass BEFORE AI review.
AI review catches semantic issues static tools miss.
```

## Process

### 1. Verify Prerequisites Passed

Before running AI review, confirm:
- [ ] Tests passed
- [ ] Lint passed
- [ ] Security scan passed

**If any failed → STOP. Fix those first.**

### 2. Generate Diff

```bash
git diff main > /tmp/review-diff.txt
```

### 3. Run Spec Compliance Review (if spec exists)

```bash
SPEC_FILE=$(ls -t docs/plans/*.md specs/*.md 2>/dev/null | head -1)

if [ -n "$SPEC_FILE" ]; then
  ollama run llama3.2 "You are reviewing if code matches spec.

SPEC:
$(cat "$SPEC_FILE")

DIFF:
$(cat /tmp/review-diff.txt)

Check:
1. Missing requirements from spec
2. Features not in spec
3. Deviations from approach

Format:
COMPLIANT: yes/no
ISSUES: list or none
RECOMMENDATIONS: list or none"
fi
```

### 4. Run Code Quality Review

```bash
ollama run gemma2 "Review this diff for bugs, security, performance, maintainability.

Be concise. Only actual problems, not style (lint handles style).

DIFF:
$(cat /tmp/review-diff.txt)

Format:
BUGS: list or none
SECURITY: list or none
PERFORMANCE: list or none
MAINTAINABILITY: list or none"
```

### 5. Address Findings

| Category | Action |
|----------|--------|
| BUGS | Fix before merge |
| SECURITY | Fix before merge |
| PERFORMANCE | Assess, fix if significant |
| MAINTAINABILITY | Fix or create follow-up issue |

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "AI review is slow" | 30 seconds now vs hours debugging later |
| "Tests are comprehensive" | Tests verify behavior. AI catches design issues. |
| "AI gave false positive" | Assess properly. AI sees patterns you miss. |
| "Ollama isn't running" | Start it: `ollama serve` |

## Red Flags - STOP

- Running AI review before tests/lint pass
- Ignoring findings without assessment
- Skipping because "Ollama is slow"
- Not reading the output

**If you catch yourself doing any of these: STOP. Follow the process.**

## Verification

```bash
# Verify Ollama is running
curl -s http://localhost:11434/api/tags | grep -q "models" && echo "Ollama running"
```

## References

- `references/ollama-setup.md` - Installing Ollama and models
- `references/prompts.md` - Review prompt templates
```

**Step 2: Write references/ollama-setup.md**

Write to `skills/quality-gates/ai-code-review/references/ollama-setup.md`:

```markdown
# Ollama Setup for AI Code Review

## Installation

### macOS

```bash
brew install ollama
```

### Linux

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### Windows

Download from https://ollama.ai

## Pull Models

```bash
# Recommended for code review
ollama pull llama3.2
ollama pull gemma2

# Alternative models
ollama pull codellama
ollama pull deepseek-coder
```

## Start Server

```bash
ollama serve
```

Or run as background service:

```bash
# macOS (after brew install)
brew services start ollama

# Linux systemd
sudo systemctl enable ollama
sudo systemctl start ollama
```

## Verify

```bash
# Check server
curl http://localhost:11434/api/tags

# Test generation
ollama run llama3.2 "Say hello"
```

## Model Selection

| Model | Best For | Size |
|-------|----------|------|
| llama3.2 | General review, spec compliance | 3B |
| gemma2 | Code quality, bugs | 9B |
| codellama | Code-specific analysis | 7B |
| deepseek-coder | Deep code understanding | 6.7B |

## Resource Requirements

- Minimum: 8GB RAM
- Recommended: 16GB+ RAM
- GPU: Optional but faster
```

**Step 3: Write references/prompts.md**

Write to `skills/quality-gates/ai-code-review/references/prompts.md`:

```markdown
# AI Review Prompt Templates

## Spec Compliance Review

```
You are reviewing if code implementation matches the specification.

SPECIFICATION:
{spec_content}

CODE DIFF:
{diff_content}

Analyze:
1. Are all requirements from the spec implemented?
2. Is anything implemented that's NOT in the spec?
3. Does the implementation approach match the spec?

Output format:
COMPLIANT: [yes/no]
MISSING_REQUIREMENTS: [list or "none"]
EXTRA_FEATURES: [list or "none"]
APPROACH_DEVIATIONS: [list or "none"]
```

## Bug Detection

```
Review this code diff for potential bugs.

DIFF:
{diff_content}

Look for:
- Null/undefined access
- Off-by-one errors
- Race conditions
- Resource leaks
- Error handling gaps
- Logic errors

Output only actual bugs found, not style issues.

BUGS: [list with file:line or "none"]
```

## Security Review

```
Review this code diff for security vulnerabilities.

DIFF:
{diff_content}

Check for:
- Injection vulnerabilities (SQL, command, XSS)
- Authentication/authorization issues
- Sensitive data exposure
- Insecure cryptography
- Path traversal

SECURITY_ISSUES: [list with severity or "none"]
```

## Performance Review

```
Review this code diff for performance issues.

DIFF:
{diff_content}

Look for:
- N+1 queries
- Unnecessary loops
- Memory leaks
- Blocking operations
- Missing caching opportunities

PERFORMANCE_ISSUES: [list or "none"]
```

## Combined Quick Review

```
Quick review of code changes.

DIFF:
{diff_content}

Report only actual problems (not style):
BUGS: [list or none]
SECURITY: [list or none]
PERFORMANCE: [list or none]

Be concise.
```
```

**Step 4: Remove .gitkeep and commit**

```bash
rm -f skills/quality-gates/ai-code-review/.gitkeep
rm -f skills/quality-gates/ai-code-review/references/.gitkeep
git add skills/quality-gates/ai-code-review/
git commit -m "feat: add ai-code-review skill"
```

---

## Phase 3: Commands

### Task 3.1: Create quality-check Command

**Files:**
- Create: `commands/quality-check.md`

**Step 1: Write command file**

Write to `commands/quality-check.md`:

```markdown
---
description: Run all quality gates on current changes (lint, security, AI review)
---

# Quality Check

Run complete quality verification on changed files.

## Process

### 1. Identify Changed Files

```bash
git diff --name-only main
```

### 2. Detect Platforms

From file extensions:
- `.ts`, `.tsx`, `.js`, `.jsx` → TypeScript/JavaScript
- `.py` → Python
- `.kt`, `.kts` → Kotlin

### 3. Run Platform-Specific Lint

For each detected platform:

**TypeScript/JavaScript:**
- **REQUIRED SKILL:** `quality-gates/lint-typescript`

**Python:**
- **REQUIRED SKILL:** `quality-gates/lint-python`

**Kotlin:**
- **REQUIRED SKILL:** `quality-gates/lint-kotlin`

### 4. Run Security Scan

- **REQUIRED SKILL:** `quality-gates/security-scanning`

### 5. Run AI Review (if Ollama available)

Check if Ollama is running:
```bash
curl -s http://localhost:11434/api/tags >/dev/null 2>&1
```

If available:
- **REQUIRED SKILL:** `quality-gates/ai-code-review`

If not available:
- Skip with message: "Ollama not running, skipping AI review"

## Output Format

```
Quality Check Results
=====================
Changed files: 5

├── Lint (TypeScript): ✓ PASS
├── Lint (Python): ✓ PASS  
├── Security Scan: ✓ PASS
└── AI Review: ✓ PASS (or SKIPPED if no Ollama)

All gates passed. Ready for PR.
```

## Failure Behavior

**Stop on first failure.** Do not continue to next gate.

```
Quality Check Results
=====================
Changed files: 5

├── Lint (TypeScript): ✗ FAIL
│   └── 3 errors in src/api.ts
│
└── [Remaining gates skipped]

Fix lint errors and re-run.
```
```

**Step 2: Remove .gitkeep and commit**

```bash
rm -f commands/.gitkeep
git add commands/quality-check.md
git commit -m "feat: add quality-check command"
```

---

### Task 3.2: Create develop Command

**Files:**
- Create: `commands/develop.md`

**Step 1: Write command file**

Write to `commands/develop.md`:

```markdown
---
description: Start feature development with planning and quality gates
---

# Develop

Start a feature with proper planning and quality enforcement.

## Process

### 1. Planning Phase

**If requirements are unclear:**
- **REQUIRED SKILL:** `superpowers:brainstorming`

**Create implementation plan:**
- **REQUIRED SKILL:** `superpowers:writing-plans`

### 2. Implementation Phase

**Execute plan task-by-task:**
- **REQUIRED SKILL:** `superpowers:executing-plans`

**For each implementation task:**
- **REQUIRED SKILL:** `superpowers:test-driven-development`

### 3. Verification Phase

**Run all quality gates:**
- **REQUIRED COMMAND:** `/devtools:quality-check`

### 4. Completion Phase

**Finish the development branch:**
- **REQUIRED SKILL:** `superpowers:finishing-a-development-branch`

## The Rule

```
NO FEATURE IS COMPLETE WITHOUT:
1. Implementation plan created
2. TDD followed for each task
3. All quality gates passing
```

## Shortcuts That Will Fail

| Shortcut | Why It Fails |
|----------|--------------|
| "Skip planning, it's simple" | Simple features have hidden complexity |
| "Write tests after" | Tests-after prove nothing |
| "Lint later" | Technical debt compounds |
| "Security can wait" | Vulnerabilities multiply |

## Quick Start

For simple features:
```
1. /devtools:develop [feature description]
2. Follow the planning prompts
3. Implement with TDD
4. /devtools:quality-check
5. Done
```
```

**Step 2: Commit**

```bash
git add commands/develop.md
git commit -m "feat: add develop command"
```

---

## Phase 4: Workflow Skills

### Task 4.1: Create android-release Skill

**Files:**
- Create: `skills/workflows/android-release/SKILL.md`
- Create: `skills/workflows/android-release/references/fastlane-setup.md`
- Create: `skills/workflows/android-release/references/signing.md`
- Create: `skills/workflows/android-release/references/playstore.md`

**Step 1: Write SKILL.md**

Write to `skills/workflows/android-release/SKILL.md`:

```markdown
---
name: android-release
description: Use when deploying Android apps to Play Store internal, beta, or production tracks
---

# Android Release

## Overview

Complete release workflow: version bump, signing, Fastlane deployment to Play Store.

## Prerequisites

- **Quality gates passed:** All tests, lint, security must pass
- **Fastlane configured:** See `references/fastlane-setup.md`
- **Signing configured:** See `references/signing.md`
- **Play Store access:** Service account with API access

## The Rule

```
NO RELEASE WITHOUT ALL QUALITY GATES PASSING
No "hotfix without tests". No "quick deploy".
Every release goes through the full pipeline.
```

## Process

### 1. Verify Quality Gates

Confirm all passed in current session:
- [ ] Tests passed
- [ ] Lint passed
- [ ] Security scan passed
- [ ] AI review passed (or skipped with justification)

**If any failed → STOP. Fix first.**

### 2. Bump Version

```bash
# Determine bump type
# patch: bug fixes (1.0.0 → 1.0.1)
# minor: new features (1.0.0 → 1.1.0)
# major: breaking changes (1.0.0 → 2.0.0)

./scripts/gradle-version.sh generate [patch|minor|major]
./scripts/gradle-version.sh update
```

### 3. Build Release

```bash
./gradlew bundleRelease
```

Verify build succeeded:
```bash
ls -la app/build/outputs/bundle/release/app-release.aab
```

### 4. Deploy to Track

**Internal (testing):**
```bash
bundle exec fastlane deploy_internal
```

**Beta (staged rollout):**
```bash
bundle exec fastlane deploy_beta rollout:0.1
```

**Production (staged rollout):**
```bash
bundle exec fastlane deploy_production rollout:0.1
```

### 5. Tag Release

```bash
VERSION=$(./scripts/gradle-version.sh latest)
git add version.properties
git commit -m "chore: bump version to $VERSION"
git tag "v$VERSION"
git push origin main
git push origin "v$VERSION"
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Hotfix, no time for tests" | Hotfixes need tests MORE. Users are affected. |
| "Just metadata change" | Still goes through pipeline. No exceptions. |
| "Already tested on device" | Manual ≠ automated. Run the pipeline. |
| "Rollback is easy" | Rollback means users got bad build. Prevent it. |

## Red Flags - STOP

- Deploying without quality gates passing
- Skipping version bump
- Direct to production without staged rollout
- "Quick fix" bypassing process

**If you catch yourself doing any of these: STOP. Follow the process.**

## Verification

```bash
# Verify release uploaded
bundle exec fastlane run validate_play_store_json_key

# Check Play Console for new release
```

## References

- `references/fastlane-setup.md` - Fastlane configuration
- `references/signing.md` - Keystore and signing config
- `references/playstore.md` - Play Store tracks and rollout
```

**Step 2: Write references/fastlane-setup.md**

Write to `skills/workflows/android-release/references/fastlane-setup.md`:

```markdown
# Fastlane Setup for Android

## Prerequisites

- Ruby 3.3.x (NOT 3.4+, Fastlane incompatible)
- Bundler

## Installation

### Create Gemfile

```ruby
source "https://rubygems.org"

ruby "~> 3.3.0"

gem "fastlane", "~> 2.220"
```

### Install

```bash
bundle install
```

### Initialize Fastlane

```bash
bundle exec fastlane init
```

## Configuration

### `fastlane/Appfile`

```ruby
json_key_file(ENV['PLAY_STORE_SERVICE_ACCOUNT'] || "service-account.json")
package_name("com.example.app")
```

### `fastlane/Fastfile`

```ruby
default_platform(:android)

platform :android do
  desc "Deploy to internal track"
  lane :deploy_internal do
    gradle(task: "bundleRelease")
    upload_to_play_store(
      track: "internal",
      release_status: "completed",
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Deploy to beta track"
  lane :deploy_beta do |options|
    gradle(task: "bundleRelease")
    rollout = options[:rollout] || 1.0
    upload_to_play_store(
      track: "beta",
      release_status: rollout < 1.0 ? "inProgress" : "completed",
      rollout: rollout < 1.0 ? rollout.to_s : nil,
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Deploy to production track"
  lane :deploy_production do |options|
    gradle(task: "bundleRelease")
    rollout = options[:rollout] || 0.1
    upload_to_play_store(
      track: "production",
      release_status: rollout < 1.0 ? "inProgress" : "completed",
      rollout: rollout < 1.0 ? rollout.to_s : nil,
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end
end
```

## Verification

```bash
bundle exec fastlane lanes
# Should list all available lanes
```
```

**Step 3: Write references/signing.md**

Write to `skills/workflows/android-release/references/signing.md`:

```markdown
# Android Signing Configuration

## Keystore Generation

**IMPORTANT:** Production keystores should be generated in CI, not locally.

### For Local Development/Testing

```bash
keytool -genkey -v \
  -keystore debug.keystore \
  -alias debug \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

### For Production (CI)

Generate in CI environment, store securely (GitHub Secrets, etc.)

## Gradle Configuration

### `app/build.gradle.kts`

```kotlin
android {
    signingConfigs {
        create("release") {
            val props = Properties().apply {
                val file = rootProject.file("keystore.properties")
                if (file.exists()) file.inputStream().use { load(it) }
            }
            storeFile = file(props.getProperty("storeFile") ?: "release.keystore")
            storePassword = props.getProperty("storePassword") ?: System.getenv("KEYSTORE_PASSWORD")
            keyAlias = props.getProperty("keyAlias") ?: "release"
            keyPassword = props.getProperty("keyPassword") ?: System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### `keystore.properties` (gitignored)

```properties
storeFile=path/to/keystore.jks
storePassword=your_store_password
keyAlias=your_key_alias
keyPassword=your_key_password
```

## CI Configuration

### GitHub Actions Secrets

- `KEYSTORE_BASE64` - Base64 encoded keystore
- `KEYSTORE_PASSWORD` - Keystore password
- `KEY_ALIAS` - Key alias
- `KEY_PASSWORD` - Key password

### Decode in CI

```yaml
- name: Decode Keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > release.keystore
```
```

**Step 4: Write references/playstore.md**

Write to `skills/workflows/android-release/references/playstore.md`:

```markdown
# Play Store Configuration

## Service Account Setup

1. Go to Google Play Console → Setup → API access
2. Create new service account
3. Grant "Release manager" permissions
4. Download JSON key file

## Tracks

| Track | Purpose | Rollout |
|-------|---------|---------|
| internal | Team testing | Immediate to testers |
| alpha | Early access | Limited users |
| beta | Public beta | Staged rollout |
| production | Public release | Staged rollout |

## Staged Rollout Strategy

### Recommended Progression

1. **Internal:** 100% to testers
2. **Beta:** 10% → 50% → 100%
3. **Production:** 5% → 20% → 50% → 100%

### Rollout Commands

```bash
# Start at 10%
bundle exec fastlane deploy_production rollout:0.1

# Increase to 50%
bundle exec fastlane increase_rollout rollout:0.5

# Full rollout
bundle exec fastlane increase_rollout rollout:1.0

# Halt if issues
bundle exec fastlane halt_rollout
```

## Monitoring

After release:
1. Check Play Console for crashes
2. Monitor user reviews
3. Watch ANR rate
4. Check uninstall metrics

## Rollback

If critical issues found:
1. Halt current rollout
2. Fix issue
3. Release new version
4. Resume rollout

**Note:** You cannot truly "rollback" on Play Store. You can only release a newer version with fixes.
```

**Step 5: Remove .gitkeep and commit**

```bash
rm -f skills/workflows/android-release/.gitkeep
rm -f skills/workflows/android-release/references/.gitkeep
git add skills/workflows/android-release/
git commit -m "feat: add android-release workflow skill"
```

---

### Task 4.2: Create npm-publish Skill (Stub)

**Files:**
- Create: `skills/workflows/npm-publish/SKILL.md`

**Step 1: Write SKILL.md stub**

Write to `skills/workflows/npm-publish/SKILL.md`:

```markdown
---
name: npm-publish
description: Use when publishing npm packages to registry
---

# npm Publish

## Overview

Publish npm packages with proper versioning and quality gates.

## Prerequisites

- **Quality gates passed:** All tests, lint, security
- **npm account:** Logged in with `npm login`
- **package.json:** Properly configured

## The Rule

```
NO PUBLISH WITHOUT ALL QUALITY GATES PASSING
No "quick patch". Every publish goes through pipeline.
```

## Process

### 1. Verify Quality Gates

All must pass:
- [ ] Tests
- [ ] Lint
- [ ] Security scan

### 2. Bump Version

```bash
npm version [patch|minor|major]
```

### 3. Build (if needed)

```bash
npm run build
```

### 4. Publish

```bash
npm publish
```

### 5. Push Tags

```bash
git push origin main --tags
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Just a typo fix" | Still needs version bump and tests |
| "Breaking change is minor" | Breaking = major version bump |

## References

TODO: Add detailed references for:
- CI/CD setup
- Monorepo publishing
- Scoped packages
```

**Step 2: Remove .gitkeep and commit**

```bash
rm -f skills/workflows/npm-publish/.gitkeep
rm -f skills/workflows/npm-publish/references/.gitkeep
git add skills/workflows/npm-publish/
git commit -m "feat: add npm-publish workflow skill (stub)"
```

---

### Task 4.3: Create pypi-publish Skill (Stub)

**Files:**
- Create: `skills/workflows/pypi-publish/SKILL.md`

**Step 1: Write SKILL.md stub**

Write to `skills/workflows/pypi-publish/SKILL.md`:

```markdown
---
name: pypi-publish
description: Use when publishing Python packages to PyPI
---

# PyPI Publish

## Overview

Publish Python packages with proper versioning and quality gates.

## Prerequisites

- **Quality gates passed:** All tests, lint, security
- **PyPI account:** API token configured
- **pyproject.toml:** Properly configured

## The Rule

```
NO PUBLISH WITHOUT ALL QUALITY GATES PASSING
No "quick patch". Every publish goes through pipeline.
```

## Process

### 1. Verify Quality Gates

All must pass:
- [ ] Tests (pytest)
- [ ] Lint (ruff)
- [ ] Security scan

### 2. Bump Version

Update version in `pyproject.toml` or use tool like `bump2version`.

### 3. Build

```bash
python -m build
```

### 4. Publish

```bash
python -m twine upload dist/*
```

### 5. Tag Release

```bash
git tag "v$(python -c 'import tomllib; print(tomllib.load(open("pyproject.toml","rb"))["project"]["version"])')"
git push origin --tags
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "TestPyPI is enough" | TestPyPI for testing, PyPI needs full pipeline |
| "Just metadata change" | Still a new version, still needs checks |

## References

TODO: Add detailed references for:
- Trusted Publishers setup
- CI/CD with GitHub Actions
- Version management
```

**Step 2: Remove .gitkeep and commit**

```bash
rm -f skills/workflows/pypi-publish/.gitkeep
rm -f skills/workflows/pypi-publish/references/.gitkeep
git add skills/workflows/pypi-publish/
git commit -m "feat: add pypi-publish workflow skill (stub)"
```

---

### Task 4.4: Create version-management Skill (Stub)

**Files:**
- Create: `skills/version-management/SKILL.md`

**Step 1: Write SKILL.md stub**

Write to `skills/version-management/SKILL.md`:

```markdown
---
name: version-management
description: Use when setting up or managing semantic versioning with git tags as source of truth
---

# Version Management

## Overview

Technology-agnostic version management using git tags as source of truth, with platform-specific adapters.

## The Rule

```
GIT TAGS ARE THE SOURCE OF TRUTH
Version files (package.json, version.properties) are caches.
Tags are authoritative.
```

## Supported Platforms

- **Gradle/Android:** `version.properties` + versionCode calculation
- **npm:** `package.json` version field
- **Python:** `pyproject.toml` or `__version__`

## Process

### Get Current Version

```bash
./scripts/version-manager.sh latest
```

### Generate Next Version

```bash
./scripts/version-manager.sh generate patch  # 1.0.0 → 1.0.1
./scripts/version-manager.sh generate minor  # 1.0.0 → 1.1.0
./scripts/version-manager.sh generate major  # 1.0.0 → 2.0.0
```

### Update Version Files

```bash
./scripts/gradle-version.sh update  # For Android
```

### Tag Release

```bash
VERSION=$(./scripts/version-manager.sh latest)
git tag "v$VERSION"
git push origin "v$VERSION"
```

## References

TODO: Add detailed references for:
- Script implementations
- Platform adapters
- CI/CD integration
```

**Step 2: Remove .gitkeep and commit**

```bash
rm -f skills/version-management/.gitkeep
rm -f skills/version-management/references/.gitkeep
git add skills/version-management/
git commit -m "feat: add version-management skill (stub)"
```

---

## Phase 5: Documentation

### Task 5.1: Create README

**Files:**
- Create: `README.md`

**Step 1: Write README.md**

```markdown
# DevTools

Quality gates and deployment workflows for AI-driven development.

## Philosophy

AI agents have 40-60% success rates on complex tasks because they rationalize shortcuts. This plugin provides:

1. **Deterministic quality gates** - Tests, lint, security scans that must pass
2. **Discipline-enforced skills** - Anti-rationalization patterns from [Superpowers](https://github.com/obra/superpowers)
3. **Local verification** - Everything runs locally, including AI review via Ollama

## Installation

```bash
# Add development marketplace (for local testing)
/plugin marketplace add /path/to/claude-devtools

# Install plugin
/plugin install devtools@devtools-dev

# Restart Claude Code
```

## Dependencies

This plugin **complements** [Superpowers](https://github.com/obra/superpowers). Install both:

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

## Commands

| Command | Purpose |
|---------|---------|
| `/devtools:quality-check` | Run all quality gates on current changes |
| `/devtools:develop` | Start feature development with planning |

## Skills

### Quality Gates

| Skill | Purpose |
|-------|---------|
| `lint-typescript` | ESLint + Prettier for TypeScript/JavaScript |
| `lint-python` | Ruff for Python |
| `lint-kotlin` | ktlint for Kotlin |
| `security-scanning` | Semgrep + OSV-Scanner |
| `ai-code-review` | Local AI review via Ollama |

### Workflows

| Skill | Purpose |
|-------|---------|
| `android-release` | Play Store deployment |
| `npm-publish` | npm package publishing |
| `pypi-publish` | PyPI package publishing |
| `version-management` | Semantic versioning with git tags |

## Integration with Superpowers

| Need | Use |
|------|-----|
| TDD process | `superpowers:test-driven-development` |
| Planning | `superpowers:writing-plans` |
| Execution | `superpowers:executing-plans` |
| Linting configs | `devtools:lint-*` |
| Security scanning | `devtools:security-scanning` |
| Android deployment | `devtools:android-release` |

## Local AI Review Setup

```bash
# Install Ollama
brew install ollama  # macOS

# Pull models
ollama pull llama3.2
ollama pull gemma2

# Start server
ollama serve
```

## Skill Writing Patterns

All skills follow Superpowers patterns:
- YAML frontmatter with triggering-only description
- <300 lines in SKILL.md
- Anti-rationalization tables
- Red flags sections
- Detailed content in `references/` subdirectory

## License

MIT
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

### Task 5.2: Clean Up and Final Commit

**Step 1: Remove any remaining .gitkeep files**

```bash
find . -name ".gitkeep" -delete
```

**Step 2: Verify structure**

```bash
tree -I '.git|node_modules|.venv' .
```

Expected output:
```
.
├── .claude-plugin
│   ├── marketplace.json
│   └── plugin.json
├── README.md
├── commands
│   ├── develop.md
│   └── quality-check.md
├── hooks
│   ├── hooks.json
│   └── session-init.md
├── skills
│   ├── quality-gates
│   │   ├── ai-code-review
│   │   │   ├── SKILL.md
│   │   │   └── references
│   │   │       ├── ollama-setup.md
│   │   │       └── prompts.md
│   │   ├── lint-kotlin
│   │   │   ├── SKILL.md
│   │   │   └── references
│   │   │       └── setup.md
│   │   ├── lint-python
│   │   │   ├── SKILL.md
│   │   │   └── references
│   │   │       └── setup.md
│   │   ├── lint-typescript
│   │   │   ├── SKILL.md
│   │   │   └── references
│   │   │       ├── config.md
│   │   │       └── setup.md
│   │   └── security-scanning
│   │       ├── SKILL.md
│   │       └── references
│   │           ├── setup.md
│   │           └── severity-guide.md
│   ├── version-management
│   │   └── SKILL.md
│   └── workflows
│       ├── android-release
│       │   ├── SKILL.md
│       │   └── references
│       │       ├── fastlane-setup.md
│       │       ├── playstore.md
│       │       └── signing.md
│       ├── npm-publish
│       │   └── SKILL.md
│       └── pypi-publish
│           └── SKILL.md
└── specs
    └── 2025-01-23-v2-plugin-rewrite.md
```

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore: complete v2 plugin structure"
```

---

## Summary

### Files Created

| Phase | Files | Count |
|-------|-------|-------|
| 1. Foundation | plugin.json, marketplace.json, hooks | 4 |
| 2. Quality Gates | 5 skills with references | 15 |
| 3. Commands | develop.md, quality-check.md | 2 |
| 4. Workflows | 4 skills with references | 10 |
| 5. Documentation | README.md | 1 |

**Total: ~32 files**

### Key Patterns Applied

1. **YAML frontmatter** with triggering-only descriptions
2. **Anti-rationalization tables** in every skill
3. **Red flags sections** for self-checking
4. **References subdirectories** for detailed content
5. **Session bootstrap hook** for context injection
6. **Commands wrapping skills** for user entry points

### Stubs to Expand Later

- `npm-publish` - needs CI/CD details
- `pypi-publish` - needs Trusted Publishers setup
- `version-management` - needs script implementations

### Testing Installation

After implementation:
```bash
/plugin marketplace add ~/claude-devtools
/plugin install devtools@devtools-dev
# Restart Claude Code
# Verify: skills should appear in skill list
```
