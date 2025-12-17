# PyPI Publishing Setup Skill

Set up automated PyPI publishing with GitHub Actions for Python projects.

## Purpose

Configure a complete PyPI publishing workflow that uses PyPI Trusted Publishers (no API tokens needed), automatic versioning with setuptools_scm, and TestPyPI for PR testing.

## What Gets Created

This skill generates 6 files:

1. **`.github/workflows/release.yml`** - Manual releases via GitHub UI
2. **`.github/workflows/test-pr.yml`** - Automatic TestPyPI publishing on PRs
3. **`.github/workflows/_reusable-test-build.yml`** - Shared test/build logic
4. **`scripts/calculate_version.sh`** - Version calculation script
5. **`pyproject.toml`** - Build system configuration (if not exists)
6. **`setup.py`** - Package metadata (if not exists)

## Prerequisites

- Python project with source code
- GitHub repository
- Git initialized with at least one commit

## Process

### 1. Gather Project Information

Extract or ask for the following:

**From existing files (if they exist):**
- Read `pyproject.toml` for project name, description
- Read `setup.py` for package metadata
- Detect Python version from `.python-version`, `pyproject.toml`, or default to `3.11`

**Ask user if not found:**
- **Package name**: What should the PyPI package be called?
  - If user has git configured, suggest: `{github-username}-{project-name}`
  - Example: `hitoshura25-my-package`
- **Author name**: From `git config user.name` or ask
- **Author email**: From `git config user.email` or ask
- **Description**: Short one-line description
- **URL**: GitHub repository URL
- **Command name** (if CLI tool): What command should install the package?
  - Example: `my-package` → users run `my-package` after install
  - Can be same as package name or different

**Derive automatically:**
- **Import name**: Package name with hyphens replaced by underscores
  - Example: `hitoshura25-my-package` → `hitoshura25_my_package`

**Configuration options:**
- **Python version**: Default `3.11` (or detect from project)
- **Test path**: Default `.` (current directory) or ask if tests/ exists
- **Verbose publish**: Default `false`

### 2. Create Project Files (If Needed)

If `pyproject.toml` doesn't exist, create it:

**Read template**: `./templates/pyproject.toml`

**Write to**: `pyproject.toml` (project root)

**No substitutions needed** - this file is static.

---

If `setup.py` doesn't exist, create it:

**Read template**: `./templates/setup.py`

**Substitute variables:**
- `{{PACKAGE_NAME}}` → Full package name (e.g., `hitoshura25-my-package`)
- `{{AUTHOR}}` → Author name
- `{{AUTHOR_EMAIL}}` → Author email
- `{{DESCRIPTION}}` → Package description
- `{{URL}}` → Project URL (GitHub)
- `{{COMMAND_NAME}}` → CLI command name (if applicable)
- `{{IMPORT_NAME}}` → Import name with underscores

**Write to**: `setup.py` (project root)

**Note**: If user doesn't want a CLI command, remove the `entry_points` section.

---

Create package directory and `__init__.py`:

```bash
mkdir -p {{IMPORT_NAME}}
```

**Create** `{{IMPORT_NAME}}/__init__.py`:
```python
"""{{PACKAGE_NAME}} package."""
__version__ = "0.1.0"
```

If CLI command specified, create `{{IMPORT_NAME}}/main.py`:
```python
"""Main module."""

def main():
    """Main entry point."""
    print("Hello from {{PACKAGE_NAME}}!")

if __name__ == "__main__":
    main()
```

### 3. Create GitHub Workflows

Create `.github/workflows/` directory:
```bash
mkdir -p .github/workflows
```

**Create release workflow:**

**Read template**: `./templates/release.yml`

**Substitute variables:**
- `{{PYTHON_VERSION}}` → Python version (e.g., `3.11`)
- `{{TEST_PATH}}` → Test path (e.g., `.` or `tests/`)
- `{{VERBOSE_PUBLISH}}` → `true` or `false`

**Write to**: `.github/workflows/release.yml`

---

**Create PR test workflow:**

**Read template**: `./templates/test-pr.yml`

**Substitute variables:**
- `{{PYTHON_VERSION}}` → Python version
- `{{TEST_PATH}}` → Test path
- `{{VERBOSE_PUBLISH}}` → `true` or `false`

**Write to**: `.github/workflows/test-pr.yml`

---

**Create reusable workflow:**

**Read template**: `./templates/_reusable-test-build.yml`

**Substitute variables:**
- `{{PYTHON_VERSION}}` → Python version
- `{{TEST_PATH}}` → Test path

**Write to**: `.github/workflows/_reusable-test-build.yml`

### 4. Create Version Script

Create `scripts/` directory:
```bash
mkdir -p scripts
```

**Read template**: `./templates/calculate_version.sh`

**No substitutions needed** - this file is static.

**Write to**: `scripts/calculate_version.sh`

**Make executable**:
```bash
chmod +x scripts/calculate_version.sh
```

### 5. User Instructions

After generating all files, provide instructions:

```
✓ PyPI publishing workflow created!

Files generated:
- .github/workflows/release.yml
- .github/workflows/test-pr.yml
- .github/workflows/_reusable-test-build.yml
- scripts/calculate_version.sh
- pyproject.toml (if new)
- setup.py (if new)
- {{IMPORT_NAME}}/__init__.py (if new)

Next steps:

1. Configure PyPI Trusted Publishers:
   
   a) For PyPI (production):
      - Go to: https://pypi.org/manage/account/publishing/
      - Add publisher:
        * Owner: {{GITHUB_USERNAME}}
        * Repository: {{REPO_NAME}}
        * Workflow: release.yml
        * Environment: leave blank
   
   b) For TestPyPI (PR testing):
      - Go to: https://test.pypi.org/manage/account/publishing/
      - Add publisher:
        * Owner: {{GITHUB_USERNAME}}
        * Repository: {{REPO_NAME}}
        * Workflow: test-pr.yml
        * Environment: leave blank

2. Commit and push the files:
   git add .
   git commit -m "Add PyPI publishing workflow"
   git push

3. Create your first release:
   - Go to: Actions → "Release to PyPI"
   - Click "Run workflow"
   - Select version bump (patch/minor/major)
   - Click "Run workflow"

The workflow will:
- ✓ Run tests
- ✓ Build package
- ✓ Publish to PyPI
- ✓ Create git tag
- ✓ Create GitHub Release

4. Test PR workflow (optional):
   - Create a PR
   - Workflow will automatically publish to TestPyPI
   - Version format: 1.0.0.dev{PR#}{RUN#}
```

## Validation

Before completing, verify:

```bash
# Check files exist
ls .github/workflows/release.yml
ls .github/workflows/test-pr.yml
ls .github/workflows/_reusable-test-build.yml
ls scripts/calculate_version.sh
ls pyproject.toml
ls setup.py

# Check script is executable
test -x scripts/calculate_version.sh && echo "✓ Script is executable"

# Check package directory
ls {{IMPORT_NAME}}/__init__.py
```

## How It Works

### Version Management

Uses **setuptools_scm** for git-based versioning:
- Versions are calculated from git tags
- No need to manually update version numbers
- Format: `v1.2.3` (tags) → `1.2.3` (PyPI package)

### Release Workflow

**Trigger**: Manual via GitHub UI

**Process**:
1. Calculate next version (patch/minor/major bump)
2. Check tag doesn't already exist
3. Run tests with calculated version
4. Build package with version override
5. **Publish to PyPI** (critical operation first)
6. Create and push git tag (only after successful publish)
7. Create GitHub Release

**Fail-safe design**: Tags only created after successful PyPI publish.

### PR Testing Workflow

**Trigger**: Automatic on pull requests

**Process**:
1. Calculate development version (1.2.3.dev{PR#}{RUN#})
2. Run tests
3. Build package
4. Publish to TestPyPI

**Benefits**: Test publishing without affecting production PyPI.

### Shared Test/Build Logic

The `_reusable-test-build.yml` workflow contains common logic:
- Checkout code
- Setup Python
- Install dependencies
- Run tests
- Build package
- Upload artifacts

Called by both release and PR workflows (DRY principle).

## Troubleshooting

**Tests not found:**
- Check `test_path` is correct
- Ensure tests exist in that directory
- Default `.` runs tests from root

**Version calculation fails:**
- Ensure git has at least one commit
- Script defaults to `v0.0.0` if no tags exist
- Check script has execute permissions

**setuptools_scm not detecting version:**
- Ensure `.git` directory exists
- Ensure `pyproject.toml` has setuptools_scm config
- Workflows use `SETUPTOOLS_SCM_PRETEND_VERSION` to override

**PyPI publish fails:**
- Check Trusted Publisher is configured correctly
- Workflow name must match exactly: `release.yml` or `test-pr.yml`
- Environment field must be blank (not used)

**Package name conflicts:**
- PyPI has flat namespace - names must be globally unique
- Use prefix (like `username-package`) to avoid conflicts
- Check availability: https://pypi.org/project/{package-name}/

## Configuration Options

All substitution variables:

```
{{PACKAGE_NAME}}     - Full PyPI package name (with hyphens)
{{IMPORT_NAME}}      - Python import name (with underscores)
{{AUTHOR}}           - Author full name
{{AUTHOR_EMAIL}}     - Author email
{{DESCRIPTION}}      - One-line package description
{{URL}}              - Project URL (usually GitHub)
{{COMMAND_NAME}}     - CLI command name (optional)
{{PYTHON_VERSION}}   - Python version (default: 3.11)
{{TEST_PATH}}        - Path to tests (default: .)
{{VERBOSE_PUBLISH}}  - true or false (default: false)
{{GITHUB_USERNAME}}  - GitHub user or org name
{{REPO_NAME}}        - Repository name
```

## Output Confirmation

```
✓ PyPI publishing configured
✓ 3 workflow files created
✓ 1 script file created
✓ Project files created/verified
✓ All files validated
✓ Instructions provided to user
```

## Next Steps

After setup:
- User configures Trusted Publishers
- User commits and pushes files
- User triggers first release
- Package is published to PyPI
