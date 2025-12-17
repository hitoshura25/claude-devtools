# Security Check Skill

Run security scans on code changes and address all findings before marking work complete.

## Purpose

Ensure code changes don't introduce security vulnerabilities. This is a **mandatory quality gate** - work is never complete with unaddressed critical/high security issues.

## Prerequisites

- Security tools must be configured (use `security-setup` skill if needed)
- Semgrep and OSV-Scanner should be available

## Scope of Responsibility

**CRITICAL DISTINCTION: Modified Files vs Unchanged Files**

### Files You Modify

**When you touch a file, you own ALL security issues in that file:**

- ✓ **CRITICAL/HIGH findings**: MUST fix before merge, no exceptions
- ✓ **MEDIUM findings**: MUST fix OR create tracking issue with justification
- ✓ **LOW findings**: Fix if trivial, otherwise document

**"Documentation" is NOT a substitute for fixing issues you can control.**

**Example:**
```
You modify src/auth.ts to add a new function:
- File has pre-existing HIGH finding: SQL injection in another function
- YOU MUST FIX IT even though you didn't introduce it
- Rationale: You're already touching the file and ensuring it's secure
```

### Files You Don't Touch

**For files not in your changeset:**

- CRITICAL/HIGH: Create tracking issue, not required to fix now
- MEDIUM/LOW: Acknowledge but not your responsibility

**How to check:**
```bash
# Files in your changeset
git diff --name-only main

# Only fix issues in these files
```

### Why This Matters

**Bad practice:**
```
✗ "I added authentication to auth.ts, but there's a pre-existing
   SQL injection. I'll document it and move on."
```

**Good practice:**
```
✓ "I'm modifying auth.ts, so I'm fixing ALL critical/high issues
   in this file, including the pre-existing SQL injection."
```

## Process

### 1. Run Security Scans

Execute security tools appropriate for the project:

**All Projects:**
```bash
# Semgrep (static analysis)
semgrep --config=auto .

# OSV-Scanner (dependency vulnerabilities)
osv-scanner --recursive .
```

**TypeScript/JavaScript:**
```bash
# npm audit (dependency check)
npm audit

# Or all at once
npm run security:scan
```

**Python:**
```bash
# pip-audit (dependency vulnerabilities)
pip-audit

# bandit (code analysis)
bandit -r . -c .bandit

# safety (vulnerability database)
safety check

# Or unified script
./scripts/security-scan.sh
```

**Kotlin/Android:**
```bash
# OWASP dependency check + Android lint
./gradlew securityScan

# Or individually
./gradlew dependencyCheckAnalyze
./gradlew lint
```

### 2. Review Scan Results

Understand the security findings:

**Example Semgrep Output:**
```
Findings:

  src/auth.ts
  ⚠️  Detected hardcoded JWT secret
      > token = jwt.sign(payload, "my-secret-key-123")
      
      Impact: Anyone who decompiles can extract the secret
      Fix: Use environment variable: process.env.JWT_SECRET
      
  src/api.ts  
  ❌  SQL injection vulnerability
      > db.query("SELECT * FROM users WHERE id = " + userId)
      
      Impact: Attacker can execute arbitrary SQL
      Fix: Use parameterized query: db.query("SELECT * FROM users WHERE id = ?", [userId])

2 findings: 1 error, 1 warning
```

**Example OSV-Scanner Output:**
```
Scanning dir:

  package-lock.json:
  
  ❌  axios@0.21.1 - CVE-2021-3749 (HIGH)
      Fixed in: 0.21.2
      Impact: Unsafe handling of special characters
      
  ⚠️  lodash@4.17.19 - CVE-2020-8203 (MODERATE)
      Fixed in: 4.17.21
      Impact: Prototype pollution
      
2 vulnerabilities found
```

### 3. Triage Findings by Severity

Prioritize issues based on severity:

**CRITICAL/HIGH - Must Fix:**
- SQL injection, XSS, command injection
- Hardcoded secrets/credentials
- Authentication bypasses
- Remote code execution vulnerabilities
- Critical dependency vulnerabilities with exploits

**MEDIUM - Should Fix (or Document Exception):**
- Weak cryptography
- Information disclosure
- Moderate dependency vulnerabilities
- Security misconfigurations

**LOW/INFO - Optional (Document if Deferred):**
- Style and best practice suggestions
- Low-risk dependencies
- Informational findings

### 4. Fix Code Issues (Semgrep Findings)

Address static analysis findings:

**Hardcoded Secrets:**
```typescript
// Before (CRITICAL)
const API_KEY = "sk_live_abc123xyz789";
const jwt = jwt.sign(payload, "my-secret-key");

// After (FIXED)
const API_KEY = process.env.API_KEY;
const jwt = jwt.sign(payload, process.env.JWT_SECRET);

// Add to .env.example (never commit .env)
// API_KEY=your_api_key_here
// JWT_SECRET=your_jwt_secret_here
```

**SQL Injection:**
```typescript
// Before (CRITICAL)
const query = `SELECT * FROM users WHERE id = ${userId}`;
db.query(query);

// After (FIXED) - Use parameterized queries
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [userId]);
```

**Path Traversal:**
```python
# Before (HIGH)
def read_file(filename):
    return open(f"/data/{filename}").read()

# After (FIXED) - Validate and sanitize
import os
def read_file(filename):
    # Prevent directory traversal
    safe_path = os.path.normpath(os.path.join("/data", filename))
    if not safe_path.startswith("/data/"):
        raise ValueError("Invalid file path")
    return open(safe_path).read()
```

**Insecure Randomness:**
```javascript
// Before (MEDIUM)
const token = Math.random().toString(36);

// After (FIXED) - Use crypto
const crypto = require('crypto');
const token = crypto.randomBytes(32).toString('hex');
```

### 5. Fix Dependency Vulnerabilities

Address vulnerable dependencies:

**Direct Dependencies (Preferred):**
```bash
# TypeScript/JavaScript - Update to fixed version
npm update axios
npm audit fix

# Python - Update to fixed version  
pip install --upgrade axios
pip-audit --fix
```

**Transitive Dependencies (Tricky):**
```bash
# If vulnerability is in a dependency's dependency:

# Option 1: Update parent package
npm update parent-package

# Option 2: Use resolutions (package.json)
{
  "resolutions": {
    "lodash": "^4.17.21"
  }
}

# Python: Use constraints
pip install "parent-package>=2.0" --constraint constraints.txt
```

**No Fix Available:**

If vulnerability has no patch yet:
1. Check if you actually use the vulnerable code path
2. Document the risk and monitoring plan
3. Consider alternative packages
4. Set up alerts for when patch is released

```json
// .security-exceptions.json
{
  "vulnerabilities": [
    {
      "package": "vulnerable-lib@1.0.0",
      "cve": "CVE-2024-12345",
      "reason": "We don't use the vulnerable function (parseUntrustedXML)",
      "mitigation": "Code review confirmed safe usage",
      "review_date": "2024-12-03",
      "owner": "security-team"
    }
  ]
}
```

### 6. Re-Run Security Scans

After fixes, verify all issues are resolved:

```bash
# Run scans again
semgrep --config=auto .
osv-scanner --recursive .
npm audit  # or appropriate command
```

Expected output:
```
✓ No security vulnerabilities found
```

Or with documented exceptions:
```
⚠️  1 medium finding (documented exception)
✓ No critical or high findings
```

### 7. Document Exceptions

For any security findings you can't fix immediately, document thoroughly:

**Create issue in tracker:**
```markdown
# Security Finding: Lodash Prototype Pollution

**Severity:** Medium  
**CVE:** CVE-2020-8203  
**Package:** lodash@4.17.19 (transitive via webpack-dev-server)

**Risk Assessment:**
- Only used in dev dependencies
- Not exposed to production
- Vulnerability requires specific attack vector not present in our usage

**Mitigation:**
- Monitoring for lodash updates
- Dev environment is isolated
- Will upgrade with webpack-dev-server@5.0 (Q1 2025)

**Accept Risk:** ✓ (approved by security team)
```

**Add inline suppression with explanation:**
```javascript
// semgrep: disable=detect-dangerous-api-usage
// Risk accepted: This is admin-only endpoint with rate limiting
function dangerousAdminOperation() {
  // ...
}
```

## Severity-Based Response

### CRITICAL Findings

**STOP WORK** until resolved:
- Remote code execution
- Authentication bypass
- Hardcoded production secrets

**Actions:**
1. Fix immediately
2. Review all recent changes for similar issues
3. Update security baseline
4. Consider hotfix release if in production

### HIGH Findings

**Must fix before merge:**
- SQL injection
- XSS vulnerabilities
- Insecure cryptography
- High-severity CVEs with exploits

**Actions:**
1. Fix in current PR/branch
2. Add tests to prevent regression
3. Document what was vulnerable

### MEDIUM Findings

**Fix or document exception:**
- Moderate CVEs
- Security misconfigurations
- Weak cryptography

**Actions:**
1. Evaluate risk vs effort
2. If deferring, create tracking issue
3. Document mitigation strategy

### LOW/INFO Findings

**Optional - document if deferring:**
- Best practice violations
- Low-risk dependencies
- Style recommendations

**Actions:**
1. Fix if easy
2. Otherwise, acknowledge and move on

## Common Security Issues and Fixes

### Secrets in Code

**Detection:**
```bash
# Semgrep detects
semgrep --config=p/secrets .
```

**Fix:**
```typescript
// Use environment variables
const apiKey = process.env.API_KEY;

// Use secret management
import { SecretManager } from '@google-cloud/secret-manager';
const secret = await secretManager.accessSecretVersion(secretName);
```

**Rotate compromised secrets:**
1. Generate new secret
2. Update in secret manager
3. Deploy with new secret
4. Revoke old secret

### Injection Vulnerabilities

**SQL Injection:**
```python
# Use parameterized queries
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

**Command Injection:**
```javascript
// Don't use shell interpolation
const { spawn } = require('child_process');
spawn('convert', ['-resize', '100x100', inputPath, outputPath]);
```

**LDAP Injection:**
```java
// Escape special characters
String safeUsername = LdapEncoder.filterEncode(username);
```

### Insecure Deserialization

```python
# Don't use pickle with untrusted data
# Use JSON instead
import json
data = json.loads(untrusted_input)
```

### Weak Cryptography

```typescript
// Use strong algorithms
const crypto = require('crypto');

// Bad: MD5, SHA1
// Good: SHA256, SHA512
const hash = crypto.createHash('sha256').update(data).digest('hex');

// Bad: DES, 3DES
// Good: AES-256
const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
```

## Output Confirmation

Before proceeding:

```
✓ Security scans completed
✓ No critical or high vulnerabilities in ANY file
✓ Medium findings in modified files: fixed OR tracked with issue
✓ Medium findings in other files: acknowledged/tracked
✓ Dependencies updated to secure versions
✓ Code changes reviewed for security issues
✓ Scope of changes clearly documented (files touched vs files untouched)
```

## Integration with CI/CD

Security checks should block merges:

**GitHub Actions:**
```yaml
- name: Security Scan
  run: |
    semgrep --config=auto --error --severity=ERROR .
    osv-scanner --recursive .
  # Fails if critical/high issues found
```

**Fail Fast:**
```bash
# Exit on first critical finding
semgrep --config=auto --error .
```

## NEVER Do These Things

**Shortcuts that undermine security:**

1. ✗ **NEVER** say "I'll document this issue" to avoid fixing critical/high findings in files you modify
2. ✗ **NEVER** disable security rules project-wide to make checks pass
3. ✗ **NEVER** skip security scans because "it's just a small change"
4. ✗ **NEVER** blame pre-existing issues for not fixing them in files you touch
5. ✗ **NEVER** use "documentation" as blanket escape hatch for issues you can control

**What TO do instead:**

1. ✓ Fix issues in files you modify (incremental improvement)
2. ✓ Use inline suppressions sparingly with detailed justification
3. ✓ All changes go through security scans (no exceptions for size)
4. ✓ Take ownership: "I touched it, I ensure it's secure"
5. ✓ Document exceptions with issue links + justification only when fix is impossible

## Pre-Existing Issues: What to Fix

**Common confusion: "I didn't introduce this issue, why should I fix it?"**

### The Rule

**If you modify a file, you own its security posture.**

### Examples

**Scenario 1: Adding feature to existing file**
```typescript
// You're adding a new function to auth.ts
// Semgrep reports: Existing function has hardcoded secret (HIGH)

❌ WRONG: "I didn't add that secret, I'll document it."
✅ RIGHT: "I'm touching this file, I'll fix the secret AND add my feature."
```

**Scenario 2: Bug fix in file with vulnerabilities**
```python
# You're fixing a bug in parser.py
# Semgrep reports: SQL injection in another function (CRITICAL)

❌ WRONG: "My bug fix doesn't touch that function, not my problem."
✅ RIGHT: "I'm modifying this file, I'll fix the SQL injection too."
```

**Scenario 3: Unrelated file has issues**
```javascript
# You modified auth.js
# Semgrep reports: XSS in admin.js (which you didn't touch)

✅ RIGHT: "Not in my changeset, I'll create a tracking issue but won't fix now."
```

### Why This Policy Exists

1. **Context is loaded**: You're already reviewing/understanding the file
2. **Testing is active**: You're running tests, can verify fixes
3. **Review is happening**: PR reviewers can validate security improvements
4. **Incremental improvement**: Each change makes codebase more secure
5. **Ownership culture**: Encourages taking responsibility

## CRITICAL RULE

**NEVER** merge code with unaddressed critical/high security issues IN FILES YOU MODIFY.

**For files in your changeset:**
1. Fix ALL vulnerabilities (critical/high/medium)
2. Update dependencies
3. Only document if fix is genuinely impossible (rare)
4. Re-run until clean

**For files outside your changeset:**
1. Create tracking issues for critical/high findings
2. Include in PR description: "Known issues in X, Y - see issues #123, #124"
3. Don't block on these (but make them visible)

**Never use "documentation" as excuse to skip fixing issues you can control.**

But **always** end with acceptable security posture for files you modify.

## Emergency Procedures

**If production secret is leaked:**
1. Revoke/rotate immediately
2. Audit access logs
3. Check for unauthorized access
4. Update all instances with new secret
5. Post-mortem: How did it leak?

**If critical CVE affects production:**
1. Assess if vulnerability is exploitable
2. Apply patch immediately if available
3. If no patch: Apply workaround or take offline
4. Monitor for exploitation attempts
5. Communicate with security team

## Next Steps

After security checks pass:
- All quality gates complete (testing → linting → security)
- Code is ready for review/merge
- Consider additional security reviews for sensitive changes
