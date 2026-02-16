---
description: Run all quality gates on current changes (tests, lint, security, AI review)
---

# Quality Check

Run the complete quality verification pipeline on changed files.

## Process

### 1. Identify Scope

```bash
git diff --name-only main
```

### 2. Detect Platforms

From file extensions:
- `.ts`, `.tsx`, `.js`, `.jsx` → TypeScript/JavaScript
- `.py` → Python
- `.kt`, `.kts` → Kotlin/Android

### 3. Run Platform-Specific Lint

**For each detected platform:**

- **TypeScript/JavaScript:** Use skill `lint-typescript`
- **Python:** Use skill `lint-python`
- **Kotlin:** Use skill `lint-kotlin`

### 4. Run Security Scan

**All platforms:** Use skill `security-scanning`

### 5. Run AI Review (if available)

**If Ollama is running:** Use skill `ai-code-review`

## Output Format

```
Quality Check Results:
├── Lint (TypeScript): ✓ PASS / ✗ FAIL
├── Lint (Python): ✓ PASS / ✗ FAIL  
├── Security Scan: ✓ PASS / ✗ FAIL
└── AI Review: ✓ PASS / ✗ FAIL / ⊘ SKIPPED (Ollama not available)

Status: ALL PASSED / BLOCKED (fix issues above)
```

## Critical Rule

```
STOP ON FIRST FAILURE
Do not continue to next gate if current gate fails.
Fix the issue, then re-run from the beginning.
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Just a small change" | Small changes break things. Run all gates. |
| "Already tested manually" | Manual ≠ automated. Run all gates. |
| "Will fix lint later" | No. Fix now. Gates are not negotiable. |
| "Security scan is slow" | 30 seconds now vs incident later. Run it. |
