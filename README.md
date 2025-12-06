# Claude DevTools

A comprehensive collection of skills and commands for enforcing quality gates in software development with Claude Code.

## Overview

This repository provides Claude Code with systematic workflows for implementing features with proper quality assurance. Every code change goes through mandatory quality gates:

1. **Testing** - Write and run tests
2. **Linting** - Check code style and quality
3. **Security** - Scan for vulnerabilities

## Quick Start

### Installation

1. Clone this repository:
```bash
git clone https://github.com/hitoshura25/claude-devtools.git ~/.claude-devtools
```

2. Run the installer:
```bash
cd ~/.claude-devtools
chmod +x install.sh
./install.sh
```

   This installs skills and commands **globally** - they work in ALL projects!

   **Options:**
   - Default (symlinks): Updates auto-propagate with `git pull`
   - `./install.sh --copy`: Independent installation (won't auto-update)

3. Restart Claude Code or start a new session

### Usage

In Claude Code, use these commands:

Commands work in **all projects** automatically:

**Create a specification for a feature:**
```
/devtools:spec "Plan user authentication system with JWT"
```

**Implement a feature with full quality gates:**
```
/devtools:develop "Add user authentication with JWT"
```

**Run quality checks on existing code:**
```
/devtools:validate
```

**Just run tests:**
```
/devtools:test
```

**Just run linting:**
```
/devtools:lint
```

**Just run security scans:**
```
/devtools:security
```

**Setup PyPI publishing:**
```
/devtools:setup-pypi
```

**Setup npm publishing:**
```
/devtools:setup-npm
```

**Why `/devtools:` prefix?**
Prevents name conflicts - you can still have your own `/test` command!

## Skills

### Planning & Specification

- **`spec-creation`** - Create specification documents in `./specs/` for context retention across sessions

### Quality Gates (Granular)

These skills handle individual quality checks:

- **`testing-setup`** - Configure test framework if not already setup
- **`testing-tdd`** - Write tests, run them, fix failures
- **`linting-setup`** - Configure linter if not already setup
- **`linting-check`** - Run linter, fix issues
- **`security-setup`** - Configure security tools if not already setup
- **`security-check`** - Run security scans, address findings

### Orchestration

- **`feature-development`** - Master workflow that runs all quality gates in sequence (includes spec creation)

### Workflow Generation

- **`pypi-publishing`** - Setup automated PyPI publishing with GitHub Actions
- **`npm-publishing`** - Setup automated npm publishing with GitHub Actions

### Android Release & Publishing

Comprehensive Android app release and Play Store deployment:

- **`android-release-build-setup`** - Complete release build configuration (keystores, ProGuard, signing)
- **`android-e2e-testing-setup`** - End-to-end testing with Espresso
- **`android-release-validation`** - Validate release builds before publishing
- **`android-playstore-setup`** - Google Play Console integration
- **`android-playstore-publishing`** - GitHub Actions workflow for Play Store deployment
- **`android-playstore-pipeline`** - Complete end-to-end setup in one command

## How It Works

When you run `/devtools:develop "feature description"`, Claude:

0. **Assesses complexity** → Creates spec in `./specs/` if needed (spec-creation)
1. **Implements the feature** according to your specification
2. **Checks if tests exist** → Sets up test framework if needed (testing-setup)
3. **Writes tests** → Runs them → Fixes failures (testing-tdd)
4. **Checks if linter exists** → Sets up linter if needed (linting-setup)
5. **Runs linter** → Fixes issues (linting-check)
6. **Checks if security tools exist** → Sets up tools if needed (security-setup)
7. **Runs security scans** → Addresses findings (security-check)
8. **Updates spec** with completion status (if spec was created)
9. **Reports completion** only when ALL gates pass

**Spec Creation:** Claude intelligently decides when to create a spec based on complexity. You can explicitly request or decline with:
- `/devtools:develop "feature (create spec)"` - Always creates spec
- `/devtools:develop "feature (no spec)"` - Never creates spec
- `/devtools:develop "feature"` - AI decides based on complexity

## Supported Languages

- **TypeScript/JavaScript** - Jest/Vitest, ESLint, Prettier, Semgrep, npm audit
- **Python** - pytest, Ruff/Pylint, Semgrep, pip-audit, bandit
- **Kotlin/Android** - JUnit, ktlint, Detekt, Semgrep, OWASP Dependency-Check

## Commands Reference

### `/devtools:spec`

Create a specification document for a feature without implementing it.

**Usage:**
```
/devtools:spec "Plan user authentication system"
/devtools:spec "Design API for payment processing"
```

**What it does:**
- Analyzes feature requirements
- Explores codebase for context
- Creates spec file in `./specs/YYYY-MM-DD-feature-name.md`
- Chooses appropriate detail level (1, 2, or 3)
- Enables session resumption for complex work

### `/devtools:develop`

Implement a feature with complete quality gates.

**Usage:**
```
/devtools:develop "Add password reset functionality"
/devtools:develop "Fix bug where users can't upload images"
/devtools:develop "Refactor authentication module (create spec)"
/devtools:develop "Simple typo fix (no spec)"
```

**What it does:**
- Assesses complexity and creates spec if needed
- Implements the feature
- Sets up testing/linting/security if needed
- Writes and runs tests
- Runs linting and fixes issues
- Runs security scans
- Updates spec with completion status
- Only completes when all gates pass

**Spec control:**
- Add `(create spec)` to force spec creation
- Add `(no spec)` to skip spec creation
- Omit for AI to decide based on complexity

### `/devtools:validate`

Run all quality gates on existing code without implementing new features.

**Usage:**
```
/devtools:validate
```

**What it does:**
- Runs tests (sets up if needed)
- Runs linting (sets up if needed)
- Runs security scans (sets up if needed)
- Reports all issues found

### `/devtools:test`

Focus on testing only.

**Usage:**
```
/devtools:test "the authentication module"
/devtools:test
```

**What it does:**
- Sets up test framework if needed
- Writes/updates tests
- Runs tests until all pass

### `/devtools:lint`

Focus on linting only.

**Usage:**
```
/devtools:lint
```

**What it does:**
- Sets up linter if needed
- Runs linting checks
- Auto-fixes what's possible
- Reports remaining issues

### `/devtools:security`

Focus on security scanning only.

**Usage:**
```
/devtools:security
```

**What it does:**
- Sets up security tools if needed
- Runs Semgrep (static analysis)
- Runs OSV-Scanner (dependency vulnerabilities)
- Reports all security findings

### `/devtools:setup-pypi`

Setup automated PyPI publishing workflow for Python projects.

**Usage:**
```
/devtools:setup-pypi
```

**What it does:**
- Gathers project information (package name, author, etc.)
- Creates pyproject.toml and setup.py if needed
- Generates 3 GitHub Actions workflows (release, PR testing, reusable)
- Creates version calculation script
- Provides instructions for PyPI Trusted Publishers setup

**Features:**
- PyPI Trusted Publishers (no API tokens needed)
- Automatic versioning with setuptools_scm
- TestPyPI publishing for pull requests
- Fail-safe tag creation (only after successful publish)

### `/devtools:setup-npm`

Setup automated npm publishing workflow for TypeScript/JavaScript packages.

**Usage:**
```
/devtools:setup-npm
```

**What it does:**
- Reads package.json for package information
- Supports monorepos with package-specific paths
- Generates GitHub Actions workflow
- Provides instructions for NPM_TOKEN setup

**Features:**
- Automatic publishing on push to main
- RC (release candidate) versions for pull requests
- Monorepo support with path-based triggers
- Automatic version bumping

### `/devtools:android-release-setup`

Setup complete Android release build configuration with dual keystore strategy.

**Usage:**
```
/devtools:android-release-setup
```

**What it does:**
- Analyzes Android project structure
- Generates production keystore (CI/CD only)
- Generates local development keystore
- Configures ProGuard/R8 minification
- Updates build.gradle.kts with signing config
- Creates gradle.properties.template
- Updates .gitignore for security

**Features:**
- Dual keystore strategy (production + local dev)
- Auto-generated secure passwords
- Base64 encoding for GitHub Secrets
- ProGuard safe defaults with library-specific rules
- Dual-source credentials (env vars + gradle.properties)
- Comprehensive security warnings and documentation

## Configuration

### Project-Specific Commands

You can customize commands per project by editing `.claude/commands.json`:

```json
{
  "commands": [
    {
      "name": "develop",
      "description": "Custom develop workflow",
      "prompt": "Follow /Users/vinayakmenon/claude-devtools/skills/feature-development/SKILL.md but skip security checks for now"
    }
  ]
}
```

### Skill Customization

Skills are just markdown files. You can:
- Fork and modify for your needs
- Add project-specific requirements
- Adjust quality thresholds

## Architecture

```
claude-devtools/
├── skills/                    # The intelligence
│   ├── testing-setup/        # Setup test framework
│   ├── testing-tdd/          # Write and run tests
│   ├── linting-setup/        # Setup linter
│   ├── linting-check/        # Run linting
│   ├── security-setup/       # Setup security tools
│   ├── security-check/       # Run security scans
│   ├── feature-development/  # Orchestrates all gates
│   ├── pypi-publishing/      # PyPI workflow generation
│   │   └── templates/        # Workflow templates
│   └── npm-publishing/       # npm workflow generation
│       └── templates/        # Workflow templates
│
├── commands/                  # Claude Code commands
│   └── commands.json         # Command definitions
│
└── configs/                   # Reusable configurations (future)
    ├── semgrep/              # Security rules
    ├── eslint/               # Linting rules
    └── jest/                 # Test configs
```

## Why This Approach?

**Skills over CLI:**
- No dependencies to install
- Works across all languages
- Transparent - you can read what Claude will do
- Easy to customize per project

**Granular skills over monolithic:**
- Reusable components
- Can run individually (/test, /lint, /security)
- Easy to debug when something fails
- Can compose into different workflows

**Mandatory quality gates:**
- Catches bugs early
- Prevents security vulnerabilities
- Maintains code quality
- No shortcuts - quality is enforced

## Best Practices

1. **Always use `/develop` for new features** - ensures quality gates run
2. **Run `/validate` before pushing** - catches issues locally
3. **Don't skip security scans** - critical/high findings must be addressed
4. **Document exceptions** - if you disable a rule, explain why
5. **Keep tools updated** - regular updates catch new vulnerabilities

## Troubleshooting

**Skills not found:**
```bash
# Check symlink exists
ls -la ~/.config/claude-code/skills/user/devtools

# Recreate if needed
ln -s ~/.claude-devtools/skills ~/.config/claude-code/skills/user/devtools
```

**Commands not working:**
```bash
# Ensure commands.json exists in project
ls .claude/commands.json

# Copy from template
cp ~/.claude-devtools/commands/commands.json .claude/
```

**Quality gates taking too long:**
- Consider running only changed files for linting
- Use test filtering for large test suites
- Configure security tool exclusions

## Roadmap

### Phase 1 (Complete)
- ✅ Core quality gate skills (testing, linting, security)
- ✅ Feature development orchestration
- ✅ Claude Code commands

### Phase 2 (Complete)
- ✅ Workflow generation skills (PyPI, npm)
- ✅ PyPI Trusted Publishers support
- ✅ npm monorepo support

### Phase 3 (Planned)
- [ ] Android Play Store deployment workflow
- [ ] Project scaffolding templates
- [ ] Reusable config files

### Phase 3 (Future)
- [ ] CI/CD integration helpers
- [ ] Pre-commit hook generation
- [ ] Quality metrics tracking

## Contributing

Contributions welcome! Please:
1. Follow existing skill format
2. Test skills on real projects
3. Document any new patterns
4. Submit PR with clear description

## License

Apache-2.0

## Author

Vinayak Menon

## Links

- **Repository**: https://github.com/hitoshura25/claude-devtools
- **Issues**: https://github.com/hitoshura25/claude-devtools/issues
