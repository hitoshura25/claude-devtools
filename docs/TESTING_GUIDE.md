# Testing Guide - Claude DevTools

This guide walks you through testing your claude-devtools skills in real projects using Claude Code.

## Prerequisites

Before testing:
- ✅ Skills and commands are installed globally (see [QUICKSTART.md](../QUICKSTART.md))
- ✅ You have access to Claude Code
- ✅ You have test projects in TypeScript, Python, or Kotlin

**Important:** Commands are now **global** - no per-project setup needed!

## Quick Start Test (5 minutes)

### 1. Test Quality Gates

**Create a simple test project:**
```bash
mkdir test-quality-gates
cd test-quality-gates
git init
```

**Create a simple Python file:**
```bash
cat > calculator.py << 'EOF'
def add(a, b):
    return a + b
EOF
```

**Open Claude Code and test:**
```bash
claude

# Try the main command
> /devtools:develop "Add a subtract function"
```

**Expected behavior (2-5 minutes):**
1. ✅ Claude implements `subtract(a, b)` function
2. ✅ Detects no tests → Sets up pytest automatically
3. ✅ Writes tests for both `add` and `subtract`
4. ✅ Runs tests until they pass
5. ✅ Detects no linter → Sets up ruff automatically
6. ✅ Runs linting and fixes any issues
7. ✅ Detects no security → Sets up semgrep automatically
8. ✅ Runs security scans
9. ✅ Reports "✓ All quality gates passed"

**Verify results:**
```bash
# Tests should pass
pytest

# Linting should be clean
ruff check .

# Security scans should complete
semgrep --config=auto .
```

### 2. Test PyPI Workflow Generation (30-60 seconds)

```bash
# In the same project or a new one
> /devtools:setup-pypi
```

**Expected behavior:**
- Asks for: package name, author, description, Python version
- Creates: `pyproject.toml`, `setup.py`
- Creates: `.github/workflows/release.yml`
- Creates: `.github/workflows/test-pr.yml`
- Creates: `.github/workflows/_reusable-test-build.yml`
- Creates: `scripts/calculate_version.sh` (executable)
- Provides: PyPI Trusted Publishers setup instructions

**Verify:**
```bash
ls pyproject.toml setup.py
ls .github/workflows/
ls scripts/calculate_version.sh
```

### 3. Test npm Workflow Generation (20-40 seconds)

**For TypeScript/JavaScript project:**
```bash
mkdir test-npm-workflow
cd test-npm-workflow
npm init -y

# In Claude Code
> /devtools:setup-npm
```

**Expected behavior:**
- Reads `package.json` for configuration
- Detects if monorepo (looks for workspaces)
- Creates: `.github/workflows/publish-npm.yml`
- Provides: NPM_TOKEN setup instructions

**Verify:**
```bash
ls .github/workflows/publish-npm.yml
cat .github/workflows/publish-npm.yml
```

## Comprehensive Testing Scenarios

### Scenario 1: Existing Project with Partial Setup

**Setup:**
```bash
cd existing-python-project
# Already has pytest configured but no linting/security
```

**Test:**
```bash
> /devtools:develop "Add authentication module"
```

**Expected:**
- ✅ Uses existing pytest configuration
- ✅ Sets up ruff (first time)
- ✅ Sets up semgrep (first time)
- ✅ All quality gates pass

### Scenario 2: TypeScript Monorepo

**Setup:**
```bash
mkdir monorepo-test
cd monorepo-test
npm init -y
mkdir packages
mkdir packages/core packages/utils
```

**Test:**
```bash
> /devtools:setup-npm
```

**Expected:**
- ✅ Detects monorepo structure
- ✅ Asks which package to publish
- ✅ Creates workflow with correct paths
- ✅ Supports path-based triggers

### Scenario 3: Kotlin/Android Project

**Setup:**
```bash
# In an existing Kotlin project with Gradle
```

**Test:**
```bash
> /devtools:develop "Add input validation"
```

**Expected:**
- ✅ Detects Kotlin/Gradle
- ✅ Sets up JUnit appropriately
- ✅ Sets up ktlint
- ✅ Security scanning with appropriate tools

### Scenario 4: Bug Fix with Regression Test

**Setup:**
```bash
cd project-with-bug
```

**Test:**
```bash
> /devtools:develop "Fix off-by-one error in pagination"
```

**Expected:**
- ✅ Implements fix
- ✅ Writes regression test
- ✅ Runs all tests (including new regression test)
- ✅ All quality gates pass

### Scenario 5: Large Existing Project

**Setup:**
```bash
cd large-legacy-project
# Has 100+ files, existing tests, existing linting
```

**Test:**
```bash
> /devtools:validate
```

**Expected:**
- ✅ Uses existing test configuration
- ✅ Uses existing linter configuration
- ✅ Runs all checks
- ✅ Reports findings clearly

## Testing Individual Skills

### Test Testing Setup

```bash
cd fresh-project

# In Claude Code
> /devtools:test "the calculator module"
```

**Expected:**
- If no tests: Sets up test framework first
- Writes tests
- Runs tests until passing

### Test Linting

```bash
> /devtools:lint
```

**Expected:**
- If no linter: Sets up linter first
- Runs linting
- Fixes auto-fixable issues
- Reports remaining issues

### Test Security

```bash
> /devtools:security
```

**Expected:**
- If no security tools: Sets up tools first
- Runs security scans
- Reports findings by severity
- Documents accepted risks if any

### Test Validation

```bash
> /devtools:validate
```

**Expected:**
- Runs all three: testing, linting, security
- Uses existing configurations where available
- Reports comprehensive results

## Troubleshooting

### Commands Not Found

**Symptom:** `/devtools:develop` not recognized

**Check installation:**
```bash
ls ~/.claude/commands/devtools/
```

**Solution:**
```bash
cd ~/.claude-devtools
./install.sh
```

Restart Claude Code.

### Skills Not Loading

**Symptom:** Claude says "skill not found"

**Check installation:**
```bash
ls ~/.claude/skills/user/devtools/
```

**Solution:**
```bash
cd ~/.claude-devtools
./install.sh
```

### Quality Gates Being Skipped

**This should NOT happen.** The feature-development skill is designed to never skip phases.

**If it happens:**
1. Check that skill file is not corrupted:
   ```bash
   cat ~/.claude/skills/user/devtools/feature-development/SKILL.md
   ```
2. Reinstall:
   ```bash
   cd ~/.claude-devtools
   ./install.sh --copy
   ```

### Tests Not Running

**Check:**
1. Is test framework installed?
   ```bash
   # Python
   pip list | grep pytest
   
   # TypeScript
   npm list | grep jest
   ```

2. Are test files created?
   ```bash
   find . -name "*test*"
   ```

3. Check skill output for errors

### Linting Not Running

**Check:**
1. Is linter installed?
   ```bash
   # Python
   pip list | grep ruff
   
   # TypeScript
   npm list | grep eslint
   ```

2. Check configuration files exist:
   ```bash
   ls .ruff.toml .eslintrc* tsconfig.json
   ```

### Workflows Not Generated

**For PyPI:**
1. Check if templates exist:
   ```bash
   ls ~/.claude/skills/user/devtools/pypi-publishing/templates/
   ```

2. Re-run command:
   ```bash
   > /devtools:setup-pypi
   ```

**For npm:**
1. Check package.json exists:
   ```bash
   ls package.json
   ```

2. Check template exists:
   ```bash
   ls ~/.claude/skills/user/devtools/npm-publishing/templates/
   ```

## Expected Timings

Based on testing, here are typical execution times:

| Command | Simple Project | Complex Project |
|---------|---------------|-----------------|
| `/devtools:develop` | 2-5 min | 5-15 min |
| `/devtools:validate` | 1-3 min | 3-10 min |
| `/devtools:test` | 30 sec - 2 min | 2-5 min |
| `/devtools:lint` | 20-40 sec | 1-3 min |
| `/devtools:security` | 30 sec - 2 min | 2-5 min |
| `/devtools:setup-pypi` | 30-60 sec | 30-60 sec |
| `/devtools:setup-npm` | 20-40 sec | 20-40 sec |

**Factors that increase time:**
- First-time setup (installing tools)
- Large codebase (more files to scan)
- Complex tests (integration tests, E2E tests)
- Many linting issues to fix
- Security findings to address

## Success Criteria

A successful test should demonstrate:

1. ✅ **Automatic Tool Setup**
   - Pytest/Jest installed automatically
   - Linter configured automatically
   - Security tools installed automatically

2. ✅ **Quality Enforcement**
   - Tests must pass before completion
   - Linting must be clean before completion
   - Security findings must be addressed

3. ✅ **No Skipped Phases**
   - All quality gates run
   - No "skipping due to X" messages
   - Complete enforcement

4. ✅ **Correct Configurations**
   - Tools configured appropriately for language
   - Sane defaults used
   - Project-specific adjustments made

5. ✅ **Workflow Generation**
   - All template files generated
   - Variables correctly substituted
   - Files are syntactically valid

## Advanced Testing

### Test with Different Languages

```bash
# Python
cd python-project
> /devtools:develop "Add feature"

# TypeScript
cd typescript-project
> /devtools:develop "Add feature"

# Kotlin
cd kotlin-project
> /devtools:develop "Add feature"
```

Each should use appropriate tools:
- Python: pytest, ruff, semgrep
- TypeScript: jest/vitest, eslint, semgrep
- Kotlin: junit, ktlint, detekt

### Test Cross-Agent Compatibility

**With Codex:**
```bash
codex "Use the feature-development skill to add authentication"
```

**With Gemini:**
```bash
gemini "Follow the pypi-publishing skill to setup workflows"
```

### Test with Existing Workflows

```bash
cd project-with-github-actions

# Should detect and enhance, not overwrite
> /devtools:setup-pypi
```

## Reporting Issues

When reporting issues, include:

1. **Environment:**
   - OS and version
   - Claude Code version
   - Language/framework

2. **Installation method:**
   - Symlink or copy?
   - When installed?

3. **Command used:**
   ```bash
   /devtools:develop "what you asked"
   ```

4. **Expected vs actual behavior**

5. **Error messages** (if any)

6. **Verification:**
   ```bash
   ls ~/.claude/skills/user/devtools/
   ls ~/.claude/commands/devtools/
   ```

## Next Steps After Testing

1. ✅ Use in real projects
2. ✅ Customize skills for your workflow
3. ✅ Add project-specific quality gates
4. ✅ Share with your team
5. ✅ Contribute improvements back

---

**Ready to test!** Start with the 5-minute quick test, then try real projects. 🚀
