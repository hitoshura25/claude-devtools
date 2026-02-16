# Security Severity Guide

## Severity Levels

### CRITICAL - Fix Immediately, Block Merge

**Definition:** Exploitable vulnerability that could lead to full system compromise.

**Examples:**
- Remote Code Execution (RCE)
- SQL Injection with data exfiltration
- Authentication bypass
- Hardcoded production credentials/secrets
- Known actively exploited CVEs (CISA KEV list)
- Unauthenticated admin access

**Response:**
1. Stop all other work
2. Fix immediately
3. Review for similar issues
4. Consider disclosure if in production

### HIGH - Fix Immediately, Block Merge

**Definition:** Exploitable vulnerability with significant impact.

**Examples:**
- Cross-Site Scripting (XSS) - stored or reflected
- Path traversal / Local File Inclusion
- Server-Side Request Forgery (SSRF)
- Insecure deserialization
- Command injection
- Privilege escalation
- High-severity CVEs (CVSS 7.0-8.9)

**Response:**
1. Fix in current PR
2. Add regression test
3. Document what was vulnerable

### MEDIUM - Fix or Track with Justification

**Definition:** Vulnerability requiring specific conditions or with limited impact.

**Examples:**
- Information disclosure (stack traces, version info)
- Weak cryptography (MD5, SHA1 for security purposes)
- Missing security headers
- CSRF without sensitive actions
- Moderate CVEs (CVSS 4.0-6.9)
- Denial of Service (non-critical services)

**Response:**
1. Evaluate exploitability
2. If fixable easily: fix now
3. If complex: create tracking issue with:
   - CVE/finding ID
   - Risk assessment
   - Mitigation plan
   - Review date

### LOW - Document if Deferring

**Definition:** Best practice violation or theoretical risk.

**Examples:**
- Verbose error messages (non-sensitive)
- Missing optional security headers
- Outdated but non-vulnerable dependencies
- Code quality issues with security implications
- Low CVEs (CVSS < 4.0)

**Response:**
1. Fix if trivial
2. Otherwise document and move on
3. No tracking issue required

## Decision Matrix

| Question | Yes → | No → |
|----------|-------|------|
| Can attacker execute arbitrary code? | CRITICAL | Continue |
| Can attacker access/modify sensitive data? | HIGH | Continue |
| Can attacker access internal systems? | HIGH | Continue |
| Is there a known public exploit? | +1 severity | Continue |
| Does it require authentication? | -1 severity | Continue |
| Does it require user interaction? | -1 severity | Continue |
| Is it in a critical path? | +1 severity | Continue |

## Common Findings Reference

### Hardcoded Secrets
- **Severity:** CRITICAL if production, HIGH if dev/test
- **Fix:** Use environment variables or secret manager
- **Verify:** Rotate compromised secrets

### SQL Injection
- **Severity:** CRITICAL
- **Fix:** Use parameterized queries
- **Verify:** Test with `' OR '1'='1`

### XSS
- **Severity:** HIGH (stored), MEDIUM (reflected with user interaction)
- **Fix:** Escape output, use CSP
- **Verify:** Test with `<script>alert(1)</script>`

### Path Traversal
- **Severity:** HIGH
- **Fix:** Validate and sanitize paths, use allowlist
- **Verify:** Test with `../../../etc/passwd`

### Insecure Dependencies
- **Severity:** Matches CVE severity
- **Fix:** Update to patched version
- **Verify:** Re-run scanner after update

### Missing HTTPS
- **Severity:** HIGH for auth/sensitive data, MEDIUM otherwise
- **Fix:** Enforce HTTPS, use HSTS
- **Verify:** Check certificate and redirect

## CVSS Score Mapping

| CVSS Score | Severity |
|------------|----------|
| 9.0 - 10.0 | CRITICAL |
| 7.0 - 8.9 | HIGH |
| 4.0 - 6.9 | MEDIUM |
| 0.1 - 3.9 | LOW |

## When to Create Tracking Issue

Create issue if:
- Severity is MEDIUM and fix is non-trivial
- Fix requires architectural changes
- Dependency has no patch available yet
- Need security team review

Issue must include:
- Finding ID (CVE, Semgrep rule ID)
- Severity and CVSS if available
- Affected component
- Risk assessment (exploitability, impact)
- Mitigation plan
- Target fix date
- Owner

## When NOT to Suppress

Never suppress without justification:
- CRITICAL findings
- HIGH findings in modified files
- Findings in authentication/authorization code
- Findings in data handling code

Always require:
- Inline comment with justification
- Explanation of why it's safe
- Alternative mitigations in place
