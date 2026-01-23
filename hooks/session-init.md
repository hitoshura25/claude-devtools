<DEVTOOLS_CONTEXT>
You have access to the devtools plugin for quality gates and deployment workflows.

**Quality Gates (use before marking work complete):**
- `devtools:lint-typescript` / `devtools:lint-python` / `devtools:lint-kotlin`
- `devtools:security-scanning`
- `devtools:ai-code-review` (requires Ollama with OLMo/Gemma models)

**Deployment Workflows:**
- `devtools:android-release`
- `devtools:npm-publish`
- `devtools:pypi-publish`

**Commands:**
- `/devtools:quality-check` - Run all quality gates
- `/devtools:develop` - Start feature development with planning

**For TDD, planning, and execution methodology:** Use `superpowers` skills.

Quality gates are NOT optional. All must pass before work is complete.
</DEVTOOLS_CONTEXT>
