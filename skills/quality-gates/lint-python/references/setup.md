# Python Lint Setup

## Installation

```bash
pip install ruff
```

Or add to `requirements-dev.txt`:

```
ruff>=0.4.0
```

## Configuration

### `ruff.toml` (Standalone)

```toml
# Ruff configuration
line-length = 88
indent-width = 4
target-version = "py311"

[lint]
# Rules to enable
select = [
    "E",      # pycodestyle errors
    "W",      # pycodestyle warnings
    "F",      # Pyflakes
    "I",      # isort
    "N",      # pep8-naming
    "UP",     # pyupgrade
    "B",      # flake8-bugbear
    "A",      # flake8-builtins
    "C4",     # flake8-comprehensions
    "T20",    # flake8-print
    "SIM",    # flake8-simplify
    "ARG",    # flake8-unused-arguments
    "PTH",    # flake8-use-pathlib
    "ERA",    # eradicate (commented code)
    "RUF",    # Ruff-specific rules
]

# Rules to ignore
ignore = [
    "E501",   # Line too long (handled by formatter)
]

# Allow autofix for all enabled rules
fixable = ["ALL"]
unfixable = []

# Exclude directories
exclude = [
    ".git",
    ".venv",
    "venv",
    "__pycache__",
    "build",
    "dist",
    ".eggs",
    "migrations",
]

[lint.per-file-ignores]
# Tests can use assert and have unused arguments
"tests/**/*.py" = ["S101", "ARG"]
# __init__.py can have unused imports
"__init__.py" = ["F401"]

[lint.isort]
known-first-party = ["your_package_name"]

[format]
quote-style = "double"
indent-style = "space"
skip-magic-trailing-comma = false
line-ending = "auto"
```

### Or in `pyproject.toml`

```toml
[tool.ruff]
line-length = 88
indent-width = 4
target-version = "py311"

[tool.ruff.lint]
select = ["E", "W", "F", "I", "N", "UP", "B", "A", "C4", "T20", "SIM", "ARG", "PTH", "ERA", "RUF"]
ignore = ["E501"]
fixable = ["ALL"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
```

## Verification

```bash
# Check all Python files
ruff check .

# Check formatting
ruff format --check .

# Should show "All checks passed!" or list of issues
```

## Common Commands

```bash
# Lint check
ruff check .

# Lint with auto-fix
ruff check --fix .

# Format check
ruff format --check .

# Format (apply changes)
ruff format .

# Check specific files
ruff check src/main.py tests/test_main.py

# Show which rules triggered
ruff check --show-source .
```

## IDE Integration

### VS Code

Install Ruff extension (`charliermarsh.ruff`).

Create `.vscode/settings.json`:

```json
{
  "editor.formatOnSave": true,
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.codeActionsOnSave": {
      "source.fixAll.ruff": "explicit",
      "source.organizeImports.ruff": "explicit"
    }
  }
}
```

### PyCharm

Install Ruff plugin from JetBrains Marketplace.

## Pre-Commit Hook (Optional)

Create `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
```

Install:

```bash
pip install pre-commit
pre-commit install
```
