# Quick Start Guide - Claude DevTools

Get up and running with claude-devtools in 5 minutes.

## Installation (3 minutes)

### Step 1: Clone Repository

```bash
git clone https://github.com/<username>/claude-devtools.git ~/.claude-devtools
```

### Step 2: Run Installer

```bash
cd ~/.claude-devtools
chmod +x install.sh
./install.sh
```

**What it does:**
- Installs skills globally to `~/.claude/skills/user/devtools/`
- Installs commands globally to `~/.claude/commands/devtools/`
- Commands work in **ALL projects** automatically!

**Installation methods:**
```bash
# Symlink (default - recommended)
./install.sh
# Updates auto-propagate with git pull

# Copy (alternative - independent)
./install.sh --copy
# Won't auto-update, useful for customization
```

### Step 3: Verify Installation

```bash
# Check skills
ls ~/.claude/skills/user/devtools/
# Should see: testing-setup, pypi-publishing, etc.

# Check commands
ls ~/.claude/commands/devtools/
# Should see: develop.md, setup-pypi.md, etc.
```

## First Test (2 minutes)

### Create Test Project

```bash
mkdir ~/test-devtools
cd ~/test-devtools
git init

# Create a simple Python file
cat > calculator.py << 'EOF'
def add(a, b):
    return a + b
EOF
```

### Run Claude Code

```bash
claude
```

### Try a Command

```
/devtools:develop "Add a subtract function"
```

**Expected behavior:**
0. ✅ Assesses complexity (simple) → Skips spec creation
1. ✅ Implements `subtract(a, b)` function
2. ✅ Detects no tests → Sets up pytest
3. ✅ Writes tests for subtract
4. ✅ Runs tests until passing
5. ✅ Detects no linter → Sets up ruff
6. ✅ Runs linting and fixes issues
7. ✅ Detects no security → Sets up semgrep
8. ✅ Runs security scans
9. ✅ Reports "✓ Complete with all quality gates passed"

### Verify Results

```bash
# Tests pass
pytest

# Linting clean
ruff check .

# Security scans work
semgrep --config=auto .
```

## Available Commands

All commands work in **every project** automatically:

### Planning & Specification

```bash
/devtools:spec "feature"     # Create spec only (no implementation)
```

### Quality Gates

```bash
/devtools:develop "feature"   # Full quality gates (with auto spec)
/devtools:validate            # Run all checks
/devtools:test               # Testing only
/devtools:lint               # Linting only
/devtools:security           # Security only
```

**Spec control in /devtools:develop:**
```bash
/devtools:develop "feature (create spec)"  # Force spec
/devtools:develop "feature (no spec)"      # Skip spec
/devtools:develop "feature"                # AI decides
```

### Workflow Generation

```bash
/devtools:setup-pypi         # PyPI publishing
/devtools:setup-npm          # npm publishing
```

### See All Commands

```bash
/help
```

Look for commands marked `(user:devtools)`.

## Namespaced Commands

Commands use `/devtools:` prefix to prevent conflicts:

```
✅ /devtools:test       # From devtools
✅ /test                # Your own command
✅ /devtools:develop    # Clear ownership
```

## Understanding the Architecture

```
~/.claude/                          ← Global (all projects)
├── skills/user/devtools/ → symlink to ~/.claude-devtools/skills/
│   ├── testing-setup/
│   ├── pypi-publishing/
│   └── ...
└── commands/devtools/ → symlink to ~/.claude-devtools/commands/devtools/
    ├── develop.md
    ├── setup-pypi.md
    └── ...
```

**Key points:**
- ✅ Installed **once** globally
- ✅ Works in **all projects**
- ✅ No per-project setup
- ✅ Updates with `git pull` (if symlinked)

## Next Steps

### 1. Try Workflow Generation

```bash
cd ~/test-devtools

# In Claude Code
/devtools:setup-pypi
```

Should create:
- `pyproject.toml` and `setup.py`
- 3 GitHub Actions workflows
- `scripts/calculate_version.sh`
- Instructions for PyPI setup

### 2. Use in Real Projects

```bash
cd your-actual-project
claude

/devtools:develop "Add authentication feature"
```

### 3. See All Skills

```bash
ls ~/.claude/skills/user/devtools/
cat ~/.claude/skills/user/devtools/feature-development/SKILL.md
```

### 4. Customize (Optional)

**If you used symlinks:**
```bash
# Edit in repo, changes apply immediately
cd ~/.claude-devtools/skills/testing-setup
nano SKILL.md
# Changes live instantly
```

**If you used copies:**
```bash
# Edit installed files directly
nano ~/.claude/skills/user/devtools/testing-setup/SKILL.md
```

## Troubleshooting

### Commands Not Found

**Check installation:**
```bash
ls ~/.claude/commands/devtools/
```

**If empty:**
```bash
cd ~/.claude-devtools
./install.sh
```

**Restart Claude Code.**

### Skills Not Working

**Check installation:**
```bash
ls ~/.claude/skills/user/devtools/
```

**If empty:**
```bash
cd ~/.claude-devtools
./install.sh
```

### Updates Not Working

**If you used symlinks (default):**
```bash
cd ~/.claude-devtools
git pull
# Done! Updates immediately available
```

**If you used copies:**
```bash
cd ~/.claude-devtools
git pull
./install.sh --copy
# Must reinstall to get updates
```

## Key Concepts

### Symlink vs Copy

**Symlink (default):**
- Single source of truth
- Updates with `git pull`
- Easy to track changes
- Recommended for most users

**Copy (optional):**
- Independent installation
- Won't change unexpectedly
- Good for customization
- Use `./install.sh --copy`

### Global vs Project

**Old way (project-specific):**
```bash
# Had to do this in EVERY project
cd project1 && copy commands
cd project2 && copy commands
cd project3 && copy commands
```

**New way (global):**
```bash
# Install once, works everywhere
./install.sh
# Done! Works in ALL projects
```

### Namespacing

**Why `/devtools:` prefix?**

Prevents conflicts:
```
/devtools:test    ← From devtools (specific)
/test             ← Your own command (no conflict!)
```

Clear ownership in `/help`:
```
/devtools:develop (user:devtools)
/devtools:lint (user:devtools)
/test (user)              ← Your command
```

## Quick Reference Card

**Installation:**
```bash
git clone <repo> ~/.claude-devtools
cd ~/.claude-devtools && ./install.sh
```

**Usage:**
```bash
cd any-project
claude
/devtools:develop "feature"
```

**Updates:**
```bash
cd ~/.claude-devtools && git pull
```

**Help:**
```bash
/help
```

---

**That's it!** You're ready to use claude-devtools across all your projects. 🚀

For detailed information, see:
- [README.md](README.md) - Full documentation
- [INSTALLATION.md](INSTALLATION.md) - Platform-specific guides
- [TESTING_GUIDE.md](docs/TESTING_GUIDE.md) - Testing scenarios
