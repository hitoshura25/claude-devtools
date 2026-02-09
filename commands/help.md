---
description: List all available devtools skills and commands
---

# DevTools Help

Show available quality gates, workflows, and usage examples.

## Commands

| Command | Purpose |
|---------|---------|
| `/devtools:quality-check` | Run all quality gates on current changes |
| `/devtools:develop` | Start feature development with planning and TDD |
| `/devtools:plan` | Design feature and produce agent-ready task files for local models |
| `/devtools:agent-ready` | Break existing plan into standalone task files for local agents |
| `/devtools:sera` | Delegate implementation task to local SERA model via Goose |
| `/devtools:help` | Show this help (you're here) |

## Quality Gate Skills

Use before marking any work complete.

| Skill | When to Use |
|-------|-------------|
| `devtools:lint-typescript` | TypeScript/JavaScript files changed |
| `devtools:lint-python` | Python files changed |
| `devtools:lint-kotlin` | Kotlin files changed |
| `devtools:security-scanning` | Before any commit or PR |
| `devtools:ai-code-review` | After tests/lint pass (requires Ollama) |

## Workflow Skills

| Skill | When to Use |
|-------|-------------|
| `devtools:npm-publish` | Publishing npm packages (monorepo or single) |
| `devtools:pypi-publish` | Publishing Python packages to PyPI |
| `devtools:android-release` | Deploying Android apps to Play Store |
| `devtools:version-management` | Managing semantic versions with git tags |

## The Rule

```
QUALITY GATES ARE NOT OPTIONAL
All must pass before work is considered complete.
No exceptions. No "will fix later."
```

## Quick Start

**Check code quality:**
```
/devtools:quality-check
```

**Start a new feature:**
```
/devtools:develop Add user authentication
```

**Plan for local agent execution:**
```
/devtools:plan Add user authentication
```

**Use a specific skill:**
```
You: Run security scan on my changes
Claude: [uses devtools:security-scanning]
```

## Integration with Superpowers

DevTools provides **tooling**. For **methodology**, use Superpowers:

| Need | Use |
|------|-----|
| TDD process | `superpowers:test-driven-development` |
| Planning | `superpowers:writing-plans` |
| Execution | `superpowers:executing-plans` |

## More Information

Each skill has detailed documentation in its `references/` folder:
- Setup instructions
- Configuration options
- Troubleshooting guides
