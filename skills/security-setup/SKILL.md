# Security Setup Skill

Ensure security scanning tools are installed and configured for the project.

## Purpose

Before running security scans, verify that appropriate security tools are available. If not, install and configure recommended security scanners for static analysis and dependency checking.

## Detection Logic

Check for security tool indicators:

### Universal Tools (All Languages)

**Semgrep:**
- `.semgrep.yml` or `.semgrep/` directory with rule configs
- `semgrep` command available
- GitHub workflow with Semgrep

**OSV-Scanner:**
- `osv-scanner` command available (dependency vulnerability scanner)
- Scans lock files: `package-lock.json`, `poetry.lock`, `Pipfile.lock`, `go.sum`

### Language-Specific

**TypeScript/JavaScript:**
- `npm audit` (built into npm)
- `yarn audit` (built into yarn)
- Snyk CLI

**Python:**
- `pip-audit` for dependency scanning
- `bandit` for code analysis
- `safety` for known vulnerabilities

**Kotlin/Android:**
- OWASP Dependency-Check plugin in Gradle
- Android Lint (built-in)

## Recommended Tool Stack

For **maximum coverage with minimal setup**, use:

1. **Semgrep** - Static analysis for all languages
2. **OSV-Scanner** - Dependency vulnerability scanning
3. **Built-in tools** - Language-specific audits (npm audit, pip-audit)

## Setup Actions

### Install Semgrep

Semgrep is a fast, open-source static analysis tool that works across languages.

**Installation:**
```bash
# Via pip (recommended)
pip install semgrep

# Via Homebrew (macOS)
brew install semgrep

# Via npm (if no Python)
npm install -g semgrep
```

**Verify installation:**
```bash
semgrep --version
```

**Create basic config (optional but recommended):**

Create `.semgrep.yml`:
```yaml
rules:
  - id: detect-hardcoded-secrets
    pattern: |
      password = "..."
    message: Hardcoded password detected
    severity: ERROR
    languages: [python, javascript, typescript, java, kotlin]

  - id: detect-sql-injection
    pattern: |
      $QUERY = "SELECT ... " + $USER_INPUT
    message: Possible SQL injection
    severity: WARNING
    languages: [python, javascript, typescript, java, kotlin]
```

Or use pre-built rulesets:
```bash
# Use Semgrep registry rules (recommended)
semgrep --config=auto .
```

The `auto` config includes:
- Security rules for your languages
- Common vulnerability patterns
- Best practice checks

### Install OSV-Scanner

OSV-Scanner checks dependencies against known vulnerabilities.

**Installation:**
```bash
# Via Go (recommended)
go install github.com/google/osv-scanner/cmd/osv-scanner@latest

# Via Homebrew (macOS)
brew install osv-scanner

# Manual download from releases:
# https://github.com/google/osv-scanner/releases
```

**Verify installation:**
```bash
osv-scanner --version
```

**No configuration needed** - it auto-detects lock files.

### Language-Specific Tools

#### TypeScript/JavaScript

**npm audit (built-in):**
```bash
# Already available with npm
npm audit
```

**Optional: Snyk (for enhanced scanning):**
```bash
npm install -g snyk
snyk auth  # Requires account
```

#### Python

**pip-audit:**
```bash
pip install pip-audit
```

**bandit (code analysis):**
```bash
pip install bandit
```

Create `.bandit`:
```yaml
exclude_dirs:
  - /tests/
  - /migrations/

tests:
  - B201  # Flask debug mode
  - B301  # Pickle usage
  - B501  # Request verify=False
```

**safety (dependency check):**
```bash
pip install safety
```

#### Kotlin/Android

**OWASP Dependency-Check:**

Add to `build.gradle.kts`:
```kotlin
plugins {
    id("org.owasp.dependencycheck") version "8.4.0"
}

dependencyCheck {
    format = "ALL"
    suppressionFile = file("$projectDir/config/owasp-suppressions.xml")
}
```

**Android Lint (built-in):**
```bash
# Already available in Android projects
./gradlew lint
```

## Create Security Scan Scripts

Add convenient commands to run all security checks:

### TypeScript/JavaScript

Add to `package.json`:
```json
{
  "scripts": {
    "security:scan": "npm audit && semgrep --config=auto . && osv-scanner --recursive .",
    "security:audit": "npm audit",
    "security:semgrep": "semgrep --config=auto .",
    "security:osv": "osv-scanner --recursive ."
  }
}
```

### Python

Create `scripts/security-scan.sh`:
```bash
#!/bin/bash
set -e

echo "Running security scans..."

echo "1. Semgrep static analysis..."
semgrep --config=auto .

echo "2. OSV dependency scan..."
osv-scanner --recursive .

echo "3. pip-audit..."
pip-audit

echo "4. bandit code analysis..."
bandit -r . -c .bandit

echo "✓ All security scans complete"
```

Make executable:
```bash
chmod +x scripts/security-scan.sh
```

### Kotlin/Android

Add to `build.gradle.kts`:
```kotlin
tasks.register("securityScan") {
    dependsOn("dependencyCheckAnalyze", "lint")
    doLast {
        exec {
            commandLine("semgrep", "--config=auto", ".")
        }
        exec {
            commandLine("osv-scanner", "--recursive", ".")
        }
    }
}
```

Run with:
```bash
./gradlew securityScan
```

## Verification

Test that security tools work:

**Semgrep:**
```bash
semgrep --config=auto . --json
# Should output JSON with scan results
```

**OSV-Scanner:**
```bash
osv-scanner --recursive .
# Should scan lock files and report vulnerabilities
```

**npm audit:**
```bash
npm audit --json
# Should output audit results
```

## Initial Baseline

Run security scans for the first time:

```bash
# Run all scans
npm run security:scan  # JavaScript/TypeScript
./scripts/security-scan.sh  # Python
./gradlew securityScan  # Kotlin/Android
```

**If issues are found:**
1. Document critical/high severity issues
2. Create baseline for existing legacy issues
3. Commit to fixing new issues going forward

**Create baseline file** (for legacy projects):

`.security-baseline.json`:
```json
{
  "ignored_vulnerabilities": [
    {
      "id": "CVE-2023-12345",
      "reason": "False positive - not used in production code",
      "expires": "2024-12-31"
    }
  ]
}
```

## GitHub Actions Integration

Create `.github/workflows/security.yml`:
```yaml
name: Security Scan

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    # Run daily at 2 AM
    - cron: '0 2 * * *'

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: auto
      
      - name: Run OSV-Scanner
        uses: google/osv-scanner-action@v1
        with:
          scan-args: --recursive .
      
      - name: Run npm audit
        if: hashFiles('package-lock.json') != ''
        run: npm audit --audit-level=high
```

## Configuration Files to Create

Depending on project needs:

**`.semgrep.yml`** - Custom Semgrep rules (optional)
**`.bandit`** - Bandit config for Python (optional)
**`owasp-suppressions.xml`** - OWASP exceptions for Kotlin (optional)
**`scripts/security-scan.sh`** - Unified security scan script

## Output Confirmation

Once security tools are configured:

```
✓ Semgrep installed and configured
✓ OSV-Scanner installed
✓ npm audit/pip-audit/gradle available
✓ Security scan script created
✓ Initial baseline established (if needed)
```

## Best Practices

### Regular Scans

Security scans should run:
- ✓ On every commit (pre-commit hook)
- ✓ On every pull request (CI)
- ✓ Daily scheduled scans (catch new CVEs)
- ✓ Before releases

### Keep Tools Updated

```bash
# Update Semgrep
pip install --upgrade semgrep

# Update OSV-Scanner
go install github.com/google/osv-scanner/cmd/osv-scanner@latest

# Update npm packages
npm update
```

### Prioritize Findings

Not all issues are equal:

**Fix immediately:**
- Critical/High severity vulnerabilities
- Hardcoded secrets/passwords
- SQL injection vulnerabilities
- Remote code execution risks

**Review and plan:**
- Medium severity issues
- Dependency vulnerabilities with patches available
- Outdated dependencies

**Document and monitor:**
- Low severity informational findings
- False positives
- Legacy code issues

## Common Issues

**Too many false positives:**
- Start with `--config=auto` (balanced rules)
- Create suppressions for known false positives
- Document why each suppression exists

**Slow scans:**
- Exclude directories: `.semgrep.yml` with `exclude` patterns
- Skip test files for some checks
- Use `--max-memory` for large codebases

**Missing lock files:**
- OSV-Scanner needs lock files (package-lock.json, poetry.lock)
- Generate them: `npm install`, `poetry lock`

## Next Steps

After security tools are set up:
- Run security scans on code changes (see `security-check` skill)
- Integrate into CI/CD
- Schedule regular scans
- Create runbook for handling vulnerabilities
