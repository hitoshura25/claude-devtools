# DevTools

Quality gates and deployment workflows for AI-driven development.

## Philosophy

AI agents have 40-60% success rates on complex tasks because they rationalize shortcuts, skip verification, and don't follow multi-step processes reliably. This plugin provides:

1. **Deterministic quality gates** - Tests, lint, security scans that must pass
2. **Discipline-enforced skills** - Anti-rationalization patterns that close loopholes
3. **Local verification** - Everything runs locally, including AI review via Ollama

## Installation

```bash
# Add development marketplace (for local testing)
/plugin marketplace add ~/claude-devtools

# Install plugin
/plugin install devtools@devtools-dev

# Restart Claude Code
```

## Dependencies

This plugin complements [Superpowers](https://github.com/obra/superpowers) for methodology. Install both:

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

## Commands

| Command | Purpose |
|---------|---------|
| `/devtools:quality-check` | Run all quality gates on current changes |
| `/devtools:develop` | Start feature development with planning and TDD |

## Skills

### Quality Gates

| Skill | Purpose |
|-------|---------|
| `lint-typescript` | ESLint + Prettier for TypeScript/JavaScript |
| `lint-python` | Ruff for Python |
| `lint-kotlin` | ktlint for Kotlin/Android |
| `security-scanning` | Semgrep + OSV-Scanner for vulnerabilities |
| `ai-code-review` | Local AI review via Ollama (OLMo, Gemma) |

### Workflows

| Skill | Purpose |
|-------|---------|
| `android-release` | Play Store deployment via Fastlane |
| `npm-publish` | npm package publishing |
| `pypi-publish` | PyPI package publishing (Trusted Publishers) |
| `version-management` | Git tag-based semantic versioning |

## Integration with Superpowers

This plugin provides **tooling and domain expertise**. For **methodology**, use Superpowers:

| Need | Use |
|------|-----|
| TDD process | `superpowers:test-driven-development` |
| Planning | `superpowers:writing-plans` |
| Execution | `superpowers:executing-plans` |
| Code review process | `superpowers:subagent-driven-development` |
| Linting configs | `devtools:lint-*` |
| Security scanning | `devtools:security-scanning` |
| Android deployment | `devtools:android-release` |

## Quality Gate Flow

```
┌─────────────────────────────────────────────┐
│            AI Implementation                 │
└─────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│     LOCAL VERIFICATION (deterministic)       │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────┐  │
│  │ Tests  │→│  Lint  │→│Security│→│  AI  │  │
│  │ (TDD)  │ │        │ │ (SAST) │ │Review│  │
│  └────────┘ └────────┘ └────────┘ └──────┘  │
│       ALL MUST PASS - NO EXCEPTIONS          │
└─────────────────────────────────────────────┘
                      │
                      ▼
                 Ready for PR
```

## Local AI Review Setup

```bash
# Install Ollama
brew install ollama  # macOS

# Pull models
ollama pull olmo
ollama pull gemma3

# Start server
ollama serve
```

## Skill Design Principles

Skills in this plugin follow patterns from [Superpowers](https://github.com/obra/superpowers):

1. **Anti-rationalization tables** - Close loopholes Claude might use
2. **Red flags sections** - Explicit "stop if doing X"
3. **Triggering descriptions** - Description says WHEN to use, not WHAT it does
4. **Token efficiency** - Core process in SKILL.md, details in references/
5. **Deterministic verification** - Exact commands with expected output

## Directory Structure

```
claude-devtools/
├── .claude-plugin/
│   ├── plugin.json           # Plugin metadata
│   └── marketplace.json      # Local dev marketplace
├── commands/
│   ├── quality-check.md      # /devtools:quality-check
│   └── develop.md            # /devtools:develop
├── hooks/
│   ├── hooks.json            # Session start hook
│   └── session-init.md       # Context injected at session start
├── skills/
│   ├── quality-gates/
│   │   ├── lint-typescript/
│   │   ├── lint-python/
│   │   ├── lint-kotlin/
│   │   ├── security-scanning/
│   │   └── ai-code-review/
│   ├── workflows/
│   │   ├── android-release/
│   │   ├── npm-publish/
│   │   └── pypi-publish/
│   └── version-management/
└── README.md
```

## Contributing

1. Follow the skill design principles above
2. Include anti-rationalization tables
3. Add red flags section
4. Test with pressure scenarios before merging
5. Keep SKILL.md under 300 lines

## License

MIT
