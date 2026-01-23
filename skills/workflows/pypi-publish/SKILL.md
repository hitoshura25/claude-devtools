---
name: pypi-publish
description: Use when publishing Python packages to PyPI
---

# PyPI Publish

## Overview

Publish Python packages to PyPI with version management, quality gates, and Trusted Publishers (no API tokens needed).

## Prerequisites

- **Quality gates passed:** All tests, lint, security must pass
- **PyPI account:** With upload access
- **pyproject.toml:** Properly configured
- **Trusted Publisher:** Configured in PyPI (recommended)

## The Rule

```
NO PUBLISH WITHOUT ALL QUALITY GATES PASSING
No "quick patch". No "just a docstring update".
Every publish goes through the full pipeline.
```

## Process

### 1. Verify Quality Gates

```bash
# All must pass:
pytest
ruff check .
pip-audit
```

### 2. Verify Package Configuration

```bash
# Check pyproject.toml
cat pyproject.toml

# Verify what will be published
python -m build --sdist
tar -tzf dist/*.tar.gz
```

### 3. Update Version

In `pyproject.toml`:
```toml
[project]
version = "1.2.3"  # Update this
```

Or use `setuptools_scm` for git-based versioning:
```toml
[tool.setuptools_scm]
write_to = "src/yourpackage/_version.py"
```

### 4. Build

```bash
# Install build tools
pip install build twine

# Build
python -m build
```

Outputs:
- `dist/yourpackage-1.2.3.tar.gz` (sdist)
- `dist/yourpackage-1.2.3-py3-none-any.whl` (wheel)

### 5. Verify Build

```bash
# Check package
twine check dist/*

# Test install
pip install dist/*.whl
python -c "import yourpackage; print(yourpackage.__version__)"
```

### 6. Upload to TestPyPI (Optional)

```bash
twine upload --repository testpypi dist/*

# Test install
pip install --index-url https://test.pypi.org/simple/ yourpackage
```

### 7. Upload to PyPI

```bash
twine upload dist/*
```

### 8. Tag Release

```bash
VERSION=$(grep 'version' pyproject.toml | head -1 | cut -d'"' -f2)
git tag "v$VERSION"
git push origin main
git push origin "v$VERSION"
```

## CI/CD with Trusted Publishers

### PyPI Trusted Publisher Setup

1. Go to pypi.org → Your Projects → Manage → Publishing
2. Add new publisher:
   - Owner: your-github-username
   - Repository: your-repo
   - Workflow: publish.yml
   - Environment: pypi (optional)

### GitHub Actions Workflow

Create `.github/workflows/publish.yml`:

```yaml
name: Publish

on:
  push:
    tags:
      - 'v*'

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Required for Trusted Publishing
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install build twine pytest ruff pip-audit
          pip install -e .
      
      - name: Run tests
        run: pytest
      
      - name: Run lint
        run: ruff check .
      
      - name: Run security audit
        run: pip-audit
      
      - name: Build
        run: python -m build
      
      - name: Publish to PyPI
        uses: pypa/gh-action-pypi-publish@release/v1
        # No password needed with Trusted Publishers!
```

## Package Configuration

### Minimal pyproject.toml

```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "yourpackage"
version = "1.0.0"
description = "Package description"
readme = "README.md"
license = {text = "MIT"}
authors = [{name = "Your Name", email = "you@example.com"}]
requires-python = ">=3.9"
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
]
dependencies = [
    "requests>=2.28",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "ruff>=0.4",
    "pip-audit",
]

[project.urls]
Homepage = "https://github.com/you/yourpackage"
Documentation = "https://yourpackage.readthedocs.io"
Repository = "https://github.com/you/yourpackage"

[tool.setuptools.packages.find]
where = ["src"]
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "Just a docstring update" | Still needs version bump. Semantic versioning. |
| "Tests take too long" | Tests prevent broken publishes. Run them. |
| "TestPyPI is unnecessary" | TestPyPI catches issues before real users see them. |
| "I'll fix it in next version" | Users are affected now. Don't publish broken code. |

## Red Flags - STOP

- Publishing without running tests
- Skipping version bump
- Not using Trusted Publishers (API tokens are risky)
- Ignoring pip-audit warnings
- Publishing without testing install

**If you catch yourself doing any of these: STOP. Follow the process.**

## Verification

```bash
# Verify published version
pip index versions yourpackage

# Test installation
pip install yourpackage==1.2.3
python -c "import yourpackage; print(yourpackage.__version__)"
```

## References

- `references/pyproject.md` - Detailed pyproject.toml configuration
- `references/trusted-publishers.md` - Setting up Trusted Publishers
