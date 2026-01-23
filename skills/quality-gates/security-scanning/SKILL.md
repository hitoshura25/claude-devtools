---
name: security-scanning
description: Use when checking for security vulnerabilities in code or dependencies before commit
---

# Security Scanning

## Overview

Run Semgrep (SAST) + OSV-Scanner (dependencies) on changes. Critical/High findings must be fixed.

## Tool Stack

| Tool | Purpose | What It Catches |
|------|---------|-----------------|
| Semgrep | Static analysis | SQL injection, XSS, hardcoded secrets, path traversal |
| OSV-Scanner | Dependency scan | Known CVEs in packages |
| npm audit | JS/TS packages | npm-specific vulnerabilities |
| pip-audit | Python packages | PyPI vulnerabilities |

## The Rule

```
CRITICAL AND HIGH SEVERITY FINDINGS MUST BE FIXED
No exceptions. No "document for later".
Security vulnerabilities are not negotiable.
```

## Severity Response

| Severity | Action Required |
|----------|-----------------|
| **CRITICAL** | STOP. Fix immediately. No merge until resolved. |
| **HIGH** | Fix before merge. No exceptions. |
| **MEDIUM** | Fix OR create tracking issue with risk assessment. |
| **LOW** | Document if deferring. Fix if trivial. |

## Process

### 1. Check Setup

```bash
# Verify tools installed
semgrep --version
osv-scanner --version
```

**Not installed?** See `references/setup.md`

### 2. Run Semgrep (Code Analysis)

```bash
# Auto-detect language, use recommended rules
semgrep --config=auto --error --severity=ERROR .
```

**Flags:**
- `--config=auto` - Recommended rules for detected languages
- `--error` - Exit non-zero on findings
- `--severity=ERROR` - Focus on critical/high

### 3. Run OSV-Scanner (Dependencies)

```bash
osv-scanner --recursive .
```

### 4. Run Language-Specific Audit

**JavaScript/TypeScript:**
```bash
npm audit --audit-level=high
```

**Python:**
```bash
pip-audit
```

**Both should exit 0.**

### 5. Address Findings

**For CRITICAL/HIGH:**
1. Fix the code immediately
2. Update vulnerable dependencies
3. Re-run scan to verify fix

**For MEDIUM with no immediate fix:**
1. Create tracking issue with:
   - CVE/finding ID
   - Risk assessment
   - Mitigation plan
   - Review date
2. Add inline suppression with justification

### 6. Verify Clean

```bash
semgrep --config=auto --severity=ERROR .
osv-scanner --recursive .
# Expected: no findings or only documented LOW
```

## Common Vulnerabilities and Fixes

### Hardcoded Secrets

```typescript
// ❌ BAD
const API_KEY = "sk_live_abc123";

// ✅ GOOD
const API_KEY = process.env.API_KEY;
```

### SQL Injection

```typescript
// ❌ BAD
db.query(`SELECT * FROM users WHERE id = ${userId}`);

// ✅ GOOD
db.query('SELECT * FROM users WHERE id = ?', [userId]);
```

### Path Traversal

```python
# ❌ BAD
def read_file(filename):
    return open(f"/data/{filename}").read()

# ✅ GOOD
import os
def read_file(filename):
    safe_path = os.path.normpath(os.path.join("/data", filename))
    if not safe_path.startswith("/data/"):
        raise ValueError("Invalid path")
    return open(safe_path).read()
```

### Vulnerable Dependency

```bash
# ❌ BAD - Ignore and hope
npm audit  # Shows HIGH vulnerability

# ✅ GOOD - Update
npm update vulnerable-package
npm audit  # Clean
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "False positive" | Add inline suppression WITH justification. Don't skip scan. |
| "Only in dev dependencies" | Still a vulnerability. Still needs assessment. |
| "No known exploit" | Exploits appear without warning. Fix now. |
| "Will fix in security sprint" | Security debt compounds. Fix in this PR. |
| "I didn't introduce it" | You're modifying codebase. You own security posture. |
| "Just a small change" | Small changes introduce vulnerabilities. Scan everything. |

## Red Flags - STOP

- Skipping scan because "it's slow"
- Adding `# nosemgrep` without justification
- Ignoring HIGH findings because "no time"
- Claiming "scan passed" without running it
- Suppressing entire categories of findings

**If you catch yourself doing any of these: STOP. Fix properly.**

## Inline Suppression (When Necessary)

### Semgrep

```python
# nosemgrep: python.lang.security.audit.dangerous-system-call
# Justification: This is an admin-only CLI tool with validated input
os.system(validated_admin_command)
```

### OSV-Scanner

Create `osv-scanner.toml`:

```toml
[[IgnoredVulns]]
id = "CVE-2023-12345"
reason = "Not exploitable in our usage - we never call vulnerable function"
```

**Requirements:**
- Specific finding ID
- Detailed justification
- Expiration date for review

## Verification

```bash
# Full scan
semgrep --config=auto .
osv-scanner --recursive .

# Expected: No CRITICAL/HIGH findings
# MEDIUM/LOW: documented or fixed
```

## References

- `references/setup.md` - Tool installation
- `references/severity-guide.md` - How to triage findings
- `references/suppression-guide.md` - Proper suppression techniques
