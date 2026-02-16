---
name: ai-code-review
description: Use when code changes are ready for AI review via local Ollama models after tests and lint pass
---

# AI Code Review

## Overview

Run local AI models (OLMo, Gemma) via Ollama to review changes for spec compliance and code quality. This complements (not replaces) tests, lint, and security scans.

## Prerequisites

- Ollama installed and running
- Model available: OLMo or Gemma
- Tests, lint, and security scans already passed

## The Rule

```
AI REVIEW IS ADDITIONAL VERIFICATION, NOT A SHORTCUT
Tests, lint, and security must pass BEFORE AI review.
AI review catches semantic issues that static tools miss.
```

## When AI Review Adds Value

| Static Tools Catch | AI Review Catches |
|-------------------|-------------------|
| Syntax errors | Logic errors |
| Style violations | Design issues |
| Known CVE patterns | Subtle security flaws |
| Unused variables | Wrong algorithm choice |
| Import errors | Spec non-compliance |

## Process

### 1. Verify Prerequisites Passed

```bash
# Confirm before proceeding:
# ✓ All tests pass
# ✓ Lint is clean
# ✓ Security scan is clean

# If ANY failed → stop, fix those first
```

### 2. Check Ollama Status

```bash
# Verify Ollama is running
curl -s http://localhost:11434/api/tags | head -1

# If not running:
ollama serve &
```

### 3. Generate Review Context

```bash
# Get the diff
git diff main > /tmp/review-diff.txt

# Get line count (for context)
wc -l /tmp/review-diff.txt

# Find spec file if exists
SPEC_FILE=$(ls -t docs/plans/*.md 2>/dev/null | head -1)
echo "Spec: ${SPEC_FILE:-'No spec found'}"
```

### 4. Run Spec Compliance Review

```bash
ollama run olmo <<'EOF'
You are a code reviewer checking if implementation matches specification.

Review for:
1. MISSING: Requirements in spec not implemented
2. EXTRA: Features implemented not in spec  
3. DEVIATION: Implementation differs from specified approach

SPEC:
<Insert spec content or "No spec provided">

DIFF:
<Insert diff content>

Respond in this format:
COMPLIANT: [YES/NO]
MISSING: [list or "None"]
EXTRA: [list or "None"]  
DEVIATIONS: [list or "None"]
EOF
```

### 5. Run Code Quality Review

```bash
ollama run gemma3 <<'EOF'
Review this code diff for issues. Be concise - only report actual problems.

Check for:
1. BUGS: Logic errors, edge cases, null handling
2. SECURITY: Injection, auth bypass, data exposure
3. PERFORMANCE: N+1 queries, unnecessary loops, memory leaks
4. MAINTAINABILITY: Unclear names, missing error handling, tight coupling

Ignore style issues (lint handles those).

DIFF:
<Insert diff content>

Respond in this format:
BUGS: [list or "None"]
SECURITY: [list or "None"]
PERFORMANCE: [list or "None"]
MAINTAINABILITY: [list or "None"]
EOF
```

### 6. Address Findings

| Finding Type | Action |
|--------------|--------|
| BUGS | Fix before merge |
| SECURITY | Fix before merge |
| MISSING (spec) | Implement or clarify spec |
| PERFORMANCE | Assess impact, fix if significant |
| MAINTAINABILITY | Fix or create follow-up issue |

### 7. Re-Review if Significant Changes

If fixes were substantial, re-run AI review to verify.

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "AI review is slow" | 30 seconds now vs hours debugging later |
| "Tests are comprehensive" | Tests verify behavior. AI catches design issues. |
| "AI gave false positive" | Assess it properly. AI sees patterns you miss. |
| "Ollama isn't running" | Start it: `ollama serve` |
| "Model isn't downloaded" | Download it: `ollama pull olmo` |
| "Already manually reviewed" | Human + AI catches more than either alone |

## Red Flags - STOP

- Running AI review before tests/lint/security pass
- Ignoring AI findings without assessment
- Skipping because "Ollama is slow"
- Claiming review passed without reading output
- Dismissing all findings as "false positives"

**If you catch yourself doing any of these: STOP. Do it properly.**

## Model Selection

| Model | Best For | Speed |
|-------|----------|-------|
| `olmo` | Spec compliance, requirements | Fast |
| `gemma3` | Code quality, bugs | Medium |
| `codellama` | Code-specific review | Medium |
| `llama3` | General review | Fast |

## Verification

```bash
# Verify Ollama running
curl -s http://localhost:11434/api/tags | jq '.models[].name'

# Verify model available
ollama list | grep -E "olmo|gemma"

# Quick test
echo "Review: console.log('test')" | ollama run olmo
```

## References

- `references/ollama-setup.md` - Installing and configuring Ollama
- `references/prompts.md` - Optimized review prompts
- `references/models.md` - Model comparison and selection
