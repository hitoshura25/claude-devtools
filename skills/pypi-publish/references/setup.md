# PyPI Publishing Setup

## PyPI Account

### Create Account

1. Go to https://pypi.org/account/register/
2. Verify email
3. Enable 2FA (recommended)

### TestPyPI (for testing)

1. Go to https://test.pypi.org/account/register/
2. Separate account from production PyPI

## Trusted Publishers (Recommended)

No API tokens needed. GitHub authenticates directly with PyPI.

### Configure on PyPI

1. Log in to PyPI
2. Go to your project (or create new)
3. Settings → Publishing → Add a new publisher
4. Select "GitHub Actions"
5. Fill in:
   - **Owner**: Your GitHub username or org
   - **Repository**: Repository name
   - **Workflow name**: `publish.yml` (or your workflow file)
   - **Environment**: `pypi` (optional but recommended)

### Configure GitHub Environment (Optional)

For additional security:

1. Repository → Settings → Environments
2. Create "pypi" environment
3. Add protection rules:
   - Required reviewers
   - Restrict to main branch
   - Restrict to tags

## API Tokens (Alternative)

If not using Trusted Publishers:

### Generate Token

1. PyPI → Account Settings → API tokens
2. Create token (scope: entire account or specific project)
3. Copy token (shown only once)

### Store in GitHub

1. Repository → Settings → Secrets → Actions
2. New repository secret: `PYPI_API_TOKEN`

### Use in Workflow

```yaml
- name: Publish to PyPI
  env:
    TWINE_USERNAME: __token__
    TWINE_PASSWORD: ${{ secrets.PYPI_API_TOKEN }}
  run: twine upload dist/*
```

## Project Configuration

### pyproject.toml

```toml
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

[project]
name = "your-package"
version = "1.0.0"
description = "Short description"
readme = "README.md"
license = {text = "MIT"}
authors = [
    {name = "Your Name", email = "you@example.com"}
]
requires-python = ">=3.9"
classifiers = [
    "Development Status :: 4 - Beta",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
]
dependencies = []

[project.urls]
Homepage = "https://github.com/user/repo"
Repository = "https://github.com/user/repo"
```

### Dynamic Version with setuptools_scm

```toml
[build-system]
requires = ["setuptools>=61.0", "setuptools_scm[toml]>=6.2"]
build-backend = "setuptools.build_meta"

[project]
name = "your-package"
dynamic = ["version"]

[tool.setuptools_scm]
write_to = "src/your_package/_version.py"
```

This derives version from git tags automatically.

## Building

### Install Tools

```bash
pip install build twine
```

### Build Package

```bash
# Remove old builds
rm -rf dist/

# Build
python -m build
```

### Verify Build

```bash
# List contents
ls dist/
# your_package-1.0.0-py3-none-any.whl
# your_package-1.0.0.tar.gz

# Check metadata
twine check dist/*
```

## Publishing

### To TestPyPI (testing)

```bash
twine upload --repository testpypi dist/*
```

Install from TestPyPI:
```bash
pip install --index-url https://test.pypi.org/simple/ your-package
```

### To PyPI (production)

```bash
twine upload dist/*
```

## GitHub Actions Workflow

### Complete Workflow

```yaml
name: Publish to PyPI

on:
  push:
    tags:
      - 'v*'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -e .[dev]
      - run: pytest
      - run: ruff check .

  publish:
    needs: test
    runs-on: ubuntu-latest
    environment: pypi
    permissions:
      id-token: write

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # For setuptools_scm

      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install build tools
        run: pip install build twine

      - name: Build package
        run: python -m build

      - name: Check package
        run: twine check dist/*

      - name: Publish to PyPI
        uses: pypa/gh-action-pypi-publish@release/v1
```

## Troubleshooting

### "Invalid distribution file"

Run `twine check dist/*` to see errors.

### "File already exists"

Version already published. Bump version and rebuild.

### "Invalid credentials"

For Trusted Publishers: Check workflow name matches exactly.
For tokens: Verify token is correct and has required scope.

### "Package name taken"

Choose a different name. Check availability:
```bash
pip index versions desired-name
```
