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
