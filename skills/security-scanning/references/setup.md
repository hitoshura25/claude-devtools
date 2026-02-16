# Security Scanning Setup

## Semgrep Installation

```bash
# Via pip (recommended)
pip install semgrep

# Via Homebrew (macOS)
brew install semgrep

# Via npm
npm install -g semgrep
```

Verify:
```bash
semgrep --version
```

## OSV-Scanner Installation

```bash
# Via Homebrew (macOS)
brew install osv-scanner

# Via Go
go install github.com/google/osv-scanner/cmd/osv-scanner@latest

# Manual download
# https://github.com/google/osv-scanner/releases
```

Verify:
```bash
osv-scanner --version
```

## Language-Specific Tools

### JavaScript/TypeScript

```bash
# npm audit is built into npm
npm audit --help

# Optional: Snyk for enhanced scanning
npm install -g snyk
snyk auth
```

### Python

```bash
pip install pip-audit
```

Verify:
```bash
pip-audit --help
```

## Configuration

### Semgrep Configuration (Optional)

Create `.semgrep.yml` for custom rules:

```yaml
rules:
  - id: no-hardcoded-api-keys
    patterns:
      - pattern-regex: (api[_-]?key|apikey)\s*[:=]\s*["'][a-zA-Z0-9]{20,}["']
    message: Potential hardcoded API key
    severity: ERROR
    languages: [python, javascript, typescript]

  - id: no-console-log-in-production
    pattern: console.log(...)
    message: Remove console.log before production
    severity: WARNING
    languages: [javascript, typescript]
    paths:
      include:
        - src/**
      exclude:
        - src/**/*.test.*
```

### OSV-Scanner Configuration

Create `osv-scanner.toml` for ignoring specific vulnerabilities:

```toml
# Ignore vulnerabilities (with justification)
[[IgnoredVulns]]
id = "CVE-2023-12345"
reason = "False positive - we don't use the vulnerable code path"
ignoreUntil = "2024-12-31"  # Re-evaluate by this date

[[IgnoredVulns]]
id = "GHSA-xxxx-yyyy-zzzz"
reason = "Dev dependency only, not exposed in production"
```

## Scripts

### Unified Security Scan Script

Create `scripts/security-scan.sh`:

```bash
#!/bin/bash
set -e

echo "🔒 Running Security Scans..."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

FAILED=0

# 1. Semgrep
echo "📝 Semgrep (static analysis)..."
if semgrep --config=auto --error --severity=ERROR . 2>/dev/null; then
    echo -e "${GREEN}✓ Semgrep passed${NC}"
else
    echo -e "${RED}✗ Semgrep found issues${NC}"
    FAILED=1
fi
echo ""

# 2. OSV-Scanner
echo "📦 OSV-Scanner (dependencies)..."
if osv-scanner --recursive . 2>/dev/null; then
    echo -e "${GREEN}✓ OSV-Scanner passed${NC}"
else
    echo -e "${RED}✗ OSV-Scanner found vulnerabilities${NC}"
    FAILED=1
fi
echo ""

# 3. Language-specific
if [ -f "package-lock.json" ]; then
    echo "📦 npm audit..."
    if npm audit --audit-level=high 2>/dev/null; then
        echo -e "${GREEN}✓ npm audit passed${NC}"
    else
        echo -e "${RED}✗ npm audit found issues${NC}"
        FAILED=1
    fi
    echo ""
fi

if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    echo "📦 pip-audit..."
    if pip-audit 2>/dev/null; then
        echo -e "${GREEN}✓ pip-audit passed${NC}"
    else
        echo -e "${RED}✗ pip-audit found issues${NC}"
        FAILED=1
    fi
    echo ""
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All security scans passed${NC}"
    exit 0
else
    echo -e "${RED}✗ Security issues found - fix before merge${NC}"
    exit 1
fi
```

Make executable:
```bash
chmod +x scripts/security-scan.sh
```

## CI Integration

### GitHub Actions

Create `.github/workflows/security.yml`:

```yaml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

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

      - name: Run pip-audit
        if: hashFiles('requirements.txt') != '' || hashFiles('pyproject.toml') != ''
        run: |
          pip install pip-audit
          pip-audit
```

## Verification

```bash
# Test all tools work
semgrep --version
osv-scanner --version
npm audit --help
pip-audit --help

# Run full scan
./scripts/security-scan.sh
```
