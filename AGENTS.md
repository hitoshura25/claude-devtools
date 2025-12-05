# Available Skills

This repository provides development quality gates and workflow generation skills for AI coding agents.

## Planning & Specification Skills

### spec-creation
Create specification documents in `./specs/` folder for context retention across sessions. Intelligently decides when to create specs based on feature complexity, or honors explicit user preferences. Generates detailed implementation plans that enable new AI agents to resume work without prior context.

## Quality Gates Skills

Skills that enforce code quality through testing, linting, and security scanning.

### testing-setup
Configure test frameworks (Jest/Vitest/pytest/JUnit) if not already setup. Detects project type and installs appropriate testing tools with sensible defaults.

### testing-tdd
Write and run tests following test-driven development practices. Ensures all code changes have passing tests before completion.

### linting-setup
Configure linting tools (ESLint/Ruff/ktlint) if not already setup. Installs appropriate linters with recommended configurations for each language.

### linting-check
Run linting checks and fix all issues. Auto-fixes what's possible and ensures code meets style standards before completion.

### security-setup
Configure security scanning tools (Semgrep/OSV-Scanner) if not already setup. Installs and configures security tools for static analysis and dependency checking.

### security-check
Run security scans and address all findings. Identifies vulnerabilities and ensures critical/high severity issues are resolved.

### feature-development
Master orchestration skill that runs all quality gates in sequence. Assesses complexity and creates spec if needed (Phase 0) → implementation (Phase 1) → testing (Phase 2) → linting (Phase 3) → security scanning (Phase 4) → spec update (Phase 5) with mandatory completion of all phases.

## Workflow Generation Skills

Skills that generate GitHub Actions workflows for automated publishing.

### pypi-publishing
Setup automated PyPI publishing with GitHub Actions. Generates complete workflows using PyPI Trusted Publishers (no API tokens needed), automatic versioning with setuptools_scm, and TestPyPI support for pull requests.

### npm-publishing
Setup automated npm publishing with GitHub Actions. Generates workflows for automatic publishing on main branch pushes and RC versions for pull requests. Supports monorepos with package-specific paths.

## Supported Languages

- **TypeScript/JavaScript** - Jest/Vitest, ESLint, Prettier, Semgrep, npm audit
- **Python** - pytest, Ruff/Pylint, Semgrep, pip-audit, bandit
- **Kotlin/Android** - JUnit, ktlint, Detekt, Semgrep, OWASP Dependency-Check

## Usage

These skills work by progressive disclosure - the AI agent loads only what's needed when it's needed.

### Feature Development with Quality Gates

```
Implement JWT authentication following the feature-development skill
```

The agent will:
0. Assess complexity and create spec in ./specs/ if needed (using spec-creation skill)
1. Implement the feature
2. Setup and run tests (using testing-setup and testing-tdd skills)
3. Setup and run linting (using linting-setup and linting-check skills)
4. Setup and run security scans (using security-setup and security-check skills)
5. Update spec with completion status (if spec was created)
6. Report completion only when all gates pass

### Specification Creation

```
Create a specification for user authentication system using the spec-creation skill
```

The agent will:
1. Analyze feature requirements and complexity
2. Explore codebase for existing patterns
3. Choose appropriate detail level (1, 2, or 3)
4. Create spec file in ./specs/YYYY-MM-DD-feature-name.md
5. Confirm with user (does not implement)

### Workflow Generation

```
Setup PyPI publishing for this Python project using the pypi-publishing skill
```

The agent will:
1. Gather project information
2. Create pyproject.toml and setup.py if needed
3. Generate 3 GitHub Actions workflows
4. Create version calculation script
5. Provide instructions for PyPI Trusted Publishers setup

```
Setup npm publishing for this package using the npm-publishing skill
```

The agent will:
1. Read package.json for configuration
2. Generate GitHub Actions workflow
3. Configure for monorepo if applicable
4. Provide instructions for NPM_TOKEN setup

## Installation

See [INSTALLATION.md](INSTALLATION.md) for platform-specific installation instructions.

## Architecture

Each skill is self-contained with:
- `SKILL.md` - Instructions and metadata
- `templates/` - Template files for workflow generation
- `resources/` - Supporting documentation

Skills use simple variable substitution ({{VAR}}) rather than complex templating engines, making them transparent and easy to customize.
