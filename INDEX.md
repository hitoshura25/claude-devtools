# Claude DevTools - Skill Index

Complete catalog of all commands and skills in the claude-devtools system.

## Quick Links

- 📖 [README](README.md) - Project overview and getting started
- 🏗️ [ARCHITECTURE](ARCHITECTURE.md) - Design principles and architecture
- 📋 [Specification](specs/skills-refactoring-spec.md) - Refactoring implementation spec

## Commands

All commands are thin pass-throughs that reference skills.

### Android Commands

| Command | Description | Skill Reference |
|---------|-------------|-----------------|
| `/devtools:android-release-setup` | Setup Android release build configuration | `android-release-build-setup` |
| `/devtools:android-e2e-tests` | Setup Espresso E2E testing | `android-e2e-testing-setup` |
| `/devtools:android-release-validate` | Validate release builds | `android-release-validation` |
| `/devtools:android-playstore-setup` | Setup Play Console integration | `android-playstore-setup` |
| `/devtools:android-playstore-publish` | Create deployment workflows | `android-playstore-publishing` |
| `/devtools:android-playstore-pipeline` | Complete pipeline setup guide | Document-only orchestration |

### General Development Commands

| Command | Description | Skill Reference |
|---------|-------------|-----------------|
| `/devtools:develop` | Implement feature with quality gates | `feature-development` |
| `/devtools:test` | Setup testing framework | `testing-setup`, `testing-tdd` |
| `/devtools:lint` | Setup linter and check code | `linting-setup`, `linting-check` |
| `/devtools:security` | Setup security scanning | `security-setup`, `security-check` |
| `/devtools:validate` | Run all quality checks | Multiple skills |
| `/devtools:spec` | Create feature specification | `spec-creation` |

### Publishing Commands

| Command | Description | Skill Reference |
|---------|-------------|-----------------|
| `/devtools:setup-npm` | Setup npm publishing | `npm-publishing` |
| `/devtools:setup-pypi` | Setup PyPI publishing | `pypi-publishing` |

## Skills

### Android Release Build Skills

#### Atomic Skills (Single-Purpose)

| Skill | Description | Complexity | Reliability |
|-------|-------------|------------|-------------|
| `android-keystore-generation` | Generate production and local dev keystores | Low | ~95% |
| `android-proguard-setup` | Configure ProGuard/R8 minification | Low | ~95% |
| `android-signing-config` | Setup signing configuration | Low | ~95% |

#### Orchestrator Skills

| Skill | Description | References | Reliability |
|-------|-------------|------------|-------------|
| `android-release-build-setup` | Complete release build setup | 3 atomic skills | ~95% per skill |

### Android Testing Skills

#### Atomic Skills

| Skill | Description | Complexity | Reliability |
|-------|-------------|------------|-------------|
| `android-espresso-dependencies` | Add Espresso test dependencies | Low | ~95% |
| `android-test-structure` | Create test directory structure | Low | ~95% |
| `android-sample-tests` | Generate sample test files | Low | ~95% |

#### Orchestrator Skills

| Skill | Description | References | Reliability |
|-------|-------------|------------|-------------|
| `android-e2e-testing-setup` | Complete E2E testing setup | 3 atomic skills | ~95% per skill |

### Android Play Store Skills

#### Atomic Skills

| Skill | Description | Complexity | Reliability |
|-------|-------------|------------|-------------|
| `android-service-account-guide` | Service account creation guide | Low (documentation) | ~95% |
| `android-release-notes-structure` | Create release notes directories | Low | ~95% |
| `android-playstore-api-validation` | Validate API connection | Low | ~95% |
| `android-workflow-internal` | Generate internal track workflow | Low | ~95% |
| `android-workflow-beta` | Generate beta track workflow | Low | ~95% |
| `android-workflow-production` | Generate production workflows | Low | ~95% |

#### Orchestrator Skills

| Skill | Description | References | Reliability |
|-------|-------------|------------|-------------|
| `android-playstore-setup` | Complete Play Console setup | 3 atomic skills | ~95% per skill |
| `android-playstore-publishing` | Complete workflow generation | 3 atomic skills | ~95% per skill |

### Android Validation Skills

| Skill | Description | Complexity | Reliability |
|-------|-------------|------------|-------------|
| `android-release-validation` | Validate release builds before deployment | Medium | ~90% |

### General Development Skills

| Skill | Description | Category |
|-------|-------------|----------|
| `feature-development` | Complete feature development with quality gates | Development |
| `testing-setup` | Setup appropriate test framework | Testing |
| `testing-tdd` | Write and run tests with TDD | Testing |
| `linting-setup` | Setup project linter | Code Quality |
| `linting-check` | Run linting checks | Code Quality |
| `security-setup` | Setup security scanning tools | Security |
| `security-check` | Run security scans | Security |
| `spec-creation` | Create feature specifications | Planning |

### Publishing Skills

| Skill | Description | Category |
|-------|-------------|----------|
| `npm-publishing` | Setup automated npm publishing | Publishing |
| `pypi-publishing` | Setup automated PyPI publishing | Publishing |

## Skill Categories

### By Type

**Atomic Skills (16 total):**
- Single-purpose, 2-3 steps maximum
- ~95% reliability each
- No orchestration of other skills

**Orchestrator Skills (4 total):**
- Reference multiple atomic skills
- Provide step-by-step guidance
- User verifies each step
- ~95% reliability per atomic skill

**Validation Skills (1 total):**
- Multi-check validation
- Inherently requires multiple steps
- ~90% reliability

### By Category

**Android (13 atomic + 3 orchestrators + 1 validator):**
- Release Build (3 atomic, 1 orchestrator)
- Testing (3 atomic, 1 orchestrator)
- Play Store (6 atomic, 2 orchestrators)
- Validation (1 validator)

**General Development (6 skills):**
- Testing (2 skills)
- Linting (2 skills)
- Security (2 skills)

**Publishing (2 skills):**
- npm (1 skill)
- PyPI (1 skill)

**Planning (2 skills):**
- Feature development (1 skill)
- Spec creation (1 skill)

## Skill Dependencies

### Android Deployment Pipeline

```
android-release-build-setup (orchestrator)
  ├── android-keystore-generation (atomic)
  ├── android-proguard-setup (atomic)
  └── android-signing-config (atomic)
      ↓
android-e2e-testing-setup (orchestrator)
  ├── android-espresso-dependencies (atomic)
  ├── android-test-structure (atomic)
  └── android-sample-tests (atomic)
      ↓
android-release-validation (validator)
      ↓
android-playstore-setup (orchestrator)
  ├── android-service-account-guide (atomic)
  ├── android-release-notes-structure (atomic)
  └── android-playstore-api-validation (atomic)
      ↓
android-playstore-publishing (orchestrator)
  ├── android-workflow-internal (atomic)
  ├── android-workflow-beta (atomic)
  └── android-workflow-production (atomic)
```

## File Locations

```
claude-devtools/
├── commands/devtools/
│   ├── android-*.md (6 commands)
│   ├── develop.md
│   ├── test.md
│   ├── lint.md
│   ├── security.md
│   ├── validate.md
│   ├── spec.md
│   ├── setup-npm.md
│   └── setup-pypi.md
│
└── skills/
    ├── android-keystore-generation/SKILL.md
    ├── android-proguard-setup/SKILL.md
    ├── android-signing-config/SKILL.md
    ├── android-release-build-setup/SKILL.md (v2.0.0)
    ├── android-espresso-dependencies/SKILL.md
    ├── android-test-structure/SKILL.md
    ├── android-sample-tests/SKILL.md
    ├── android-e2e-testing-setup/SKILL.md (v2.0.0)
    ├── android-release-validation/SKILL.md
    ├── android-service-account-guide/SKILL.md
    ├── android-release-notes-structure/SKILL.md
    ├── android-playstore-api-validation/SKILL.md
    ├── android-workflow-internal/SKILL.md
    ├── android-workflow-beta/SKILL.md
    ├── android-workflow-production/SKILL.md
    ├── android-playstore-setup/SKILL.md (v2.0.0)
    ├── android-playstore-publishing/SKILL.md (v2.0.0)
    └── [other skills]/
```

## Version History

**v2.0.0 (Current):** Skills refactoring complete
- Commands converted to thin pass-throughs
- Monolithic skills decomposed into atomic skills
- Orchestrator skills reference atomic skills
- ~95% reliability per atomic skill
- PKCS12 password bug fixed

**v1.0.0:** Initial implementation
- Monolithic skills
- ~40-60% reliability for complex skills
- Command/skill duplication

## Statistics

**Total Skills:** 27
- Atomic: 16 (59%)
- Orchestrators: 4 (15%)
- Validators: 1 (4%)
- Other: 6 (22%)

**Code Reduction:**
- Commands: ~1,977 lines → ~332 lines (83% reduction)
- Skills: Decomposed into focused units

**Reliability Improvement:**
- Before: ~40-60% for complex skills
- After: ~95% per atomic skill

## Usage Guidelines

1. **Start with commands** - Use `/devtools:*` commands as entry points
2. **Commands reference skills** - Read the referenced skill file
3. **Follow skills exactly** - Execute all steps as documented
4. **Verify each step** - Run verification commands before continuing
5. **Complete all criteria** - Check all completion criteria checkboxes

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed design principles and best practices.
