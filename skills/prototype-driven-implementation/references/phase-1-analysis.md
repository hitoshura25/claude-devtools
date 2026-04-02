# Phase 1: Pipeline Analysis — Detailed Guidance

## Task Decomposition Validation

Load `tasks/<feature>/tasks.json` and validate it against the colocated
`task_schema.py`:

```bash
cd <project-root>
uv run --with pydantic python -c "
import sys
sys.path.insert(0, 'tasks/<feature>')
from task_schema import TaskDecomposition
d = TaskDecomposition.model_validate_json(open('tasks/<feature>/tasks.json').read())
print(f'Valid: {len(d.tasks)} tasks')
for t in d.tasks_in_order():
    print(f'  {t.id} [{t.task_type.value}] ({t.phase.value}): {t.title}')
"
```

If validation fails, stop and report the error. The decomposition needs fixing
before the pipeline can be generated.

After validation, extract these metrics for the user:
- Total task count
- Breakdown by type (test vs implementation)
- Breakdown by phase (scaffold, core, integration, testing, infrastructure)
- Dependency depth (longest chain from a root task to a leaf task)
- Count of tasks with tests vs without

## Working Directory and Tooling Detection

### Why Working Directory Matters

This is the single most important detection step. Executors run lint and test
commands as subprocess calls from whatever `cwd` they're given. Lint tools and
test runners are typically installed local to a service or package directory —
not globally. If the tools aren't on PATH from the working directory, every
lint and test invocation will fail with "command not found."

For Aider executors specifically, Aider appends edited filenames as paths
relative to its cwd to the lint command. This is a documented Aider behavior
that the pipeline must account for.

### Determining the Service Root

Look at the file paths in `tasks.json`. Most tasks create files under a common
prefix (e.g., `services/airflow-ingestion/plugins/...`). This common prefix is
the **service root** — the directory where tooling is installed and commands
should run from.

To detect it:
1. Collect all file paths from all tasks
2. Find the longest common directory prefix
3. Verify this directory contains tooling config (e.g., `pyproject.toml`,
   `package.json`, `build.gradle`, `Makefile`)

### Tooling Command Detection — The Critical Rule

**Commands must work as isolated subprocess calls from the service root with
no activated environment.** Executors and the pipeline run tools via
`subprocess.run(cmd, cwd=service_root)`. No venv is activated. No `.bashrc`
is sourced. The command must be self-contained.

This means bare tool names like `ruff` or `pytest` will NOT work if they're
installed in a project-local virtual environment. Each language ecosystem has
its own mechanism for invoking locally-installed tools:

| Ecosystem | Tool invocation pattern | Example lint | Example test |
|-----------|------------------------|-------------|-------------|
| Python + uv | `uv run <tool>` | `uv run ruff check` | `uv run pytest tests/foo.py -x` |
| Python + pip/venv | Activate or use full path | `.venv/bin/ruff check` | `.venv/bin/pytest tests/foo.py -x` |
| Node/npm | `npx <tool>` | `npx eslint` | `npx jest tests/foo.test.ts` |
| Node/yarn | `yarn <tool>` | `yarn eslint` | `yarn jest tests/foo.test.ts` |
| Gradle | `./gradlew <task>` | `./gradlew ktlintCheck` | `./gradlew test --tests Foo` |
| Go | Tools are compiled binaries | `golangci-lint run` | `go test ./...` |
| Rust | `cargo <cmd>` | `cargo clippy` | `cargo test` |

### Auto-Fix Detection

Check whether the detected linter supports an auto-fix mode. The design doc's
Tooling section (produced by the planning skill) records this, but verify it
independently if the Tooling section is missing.

| Ecosystem | Linter | Auto-fix command | Verify with |
|-----------|--------|------------------|-------------|
| Python | ruff | `uv run ruff check --fix` | Unsort an import, run fix, check it resolves |
| TypeScript/JS | eslint | `npx eslint --fix` | Add trailing comma style error, run fix |
| Rust | clippy | `cargo clippy --fix` | Introduce a clippy-fixable pattern |
| Go | goimports | `goimports -w` | Unsort imports, run, verify |
| Kotlin | ktlint | `ktlint -F` | Introduce import ordering error |

Record the result:
- If auto-fix works: `DEFAULT_LINT_FIX_CMD = "<detected command>"`
- If not available: `DEFAULT_LINT_FIX_CMD = None`

### Per-Task Working Directory

Most tasks share the service root as their working directory. Exceptions:

1. If `phase == "scaffold"` → cwd = project root (service dir doesn't exist yet)
2. If all files share the service root prefix → cwd = service root
3. If files are outside the service tree → cwd = project root or a custom dir

Store overrides in `TASK_WORKING_DIRS: dict[str, str]`.

### File Path Rebasing

File paths from `tasks.json` are relative to the project root. For tasks
running from the service root, these must be rebased:

```
project root:    /Users/me/my-project/
service root:    /Users/me/my-project/services/my-service/
task file path:  services/my-service/plugins/client.py    (from tasks.json)
rebased path:    plugins/client.py                         (for Aider --file)
```

Scaffold tasks run from the project root — no rebasing needed.

**Note:** Path rebasing only matters for Aider executors (which use `--file` flags).
Claude and Gemini CLIs edit files via their built-in tools and work from the cwd —
file paths are included in the prompt text instead.

## Per-Task Test Command Derivation

For each task, compose the test command using the detected runner pattern:

### Test tasks (`task_type: "test"`)

Tests must FAIL (no implementation exists yet). Command used only for pipeline
verification, never passed to the executor's internal test loop.

### Implementation tasks (`task_type: "implementation"`)

Tests must PASS. For Aider executors, the test command is passed via
`--auto-test`. For Claude/Gemini executors, the pipeline's `verify_task`
handles testing independently.

### Tasks with no tests

Lint-only verification (or no verification for scaffold tasks before bootstrap).

## Bootstrap Detection

Look at the scaffold-phase tasks. If any task creates a project config file
(`pyproject.toml`, `package.json`, `build.gradle`), the pipeline needs a
bootstrap step after that task:

| Config file created | Bootstrap command |
|-------------------|------------------|
| `pyproject.toml` + uv | `uv sync` |
| `pyproject.toml` + pip | `pip install -e ".[dev]"` |
| `package.json` + npm | `npm install` |
| `package.json` + yarn | `yarn install` |
| `build.gradle` | `./gradlew build` |
| `Cargo.toml` | `cargo build` |

## Executor Detection and Role Assignment

### Detect Available Executors

Check which coding agent CLIs are available on the system:

```bash
# Aider
which aider && aider --version

# Claude Code
which claude && claude --version

# Gemini CLI
which gemini && gemini --version
```

For Aider, also check what model backends are reachable:

```bash
# LM Studio local models
curl -s http://localhost:1234/v1/models

# Cloud API keys
[ -n "$GEMINI_API_KEY" ] && echo "Gemini API key: set"
[ -n "$ANTHROPIC_API_KEY" ] && echo "Anthropic API key: set"
[ -n "$OPENAI_API_KEY" ] && echo "OpenAI API key: set"
```

For Claude CLI, verify Pro plan auth works:
```bash
claude -p "hello" --max-turns 1 2>/dev/null && echo "Claude CLI: authenticated"
```

For Gemini CLI, verify auth:
```bash
gemini -p "hello" --output-format json 2>/dev/null && echo "Gemini CLI: authenticated"
```

### Propose Executor Configuration

Present the detected executors and propose role assignments. The pipeline uses
three roles:

- **test** — writes test files. Benefits from a strong executor that produces
  real assertions and proper mock setups.
- **implementation** — writes production code constrained by pre-written tests.
  Local/cheap executors work well here.
- **scaffold** — creates project structure, config files. Any capable executor.

Each role maps to an ordered list of executor names (the escalation chain).

Present the proposal like this:

```
### Executor Configuration

Detected executors:
  aider-local-qwen:   aider + lm_studio/qwen/qwen3-coder-30b (localhost:1234)
  claude:             claude CLI (Pro plan, authenticated)
  gemini-flash:       gemini CLI + gemini-2.5-flash (GEMINI_API_KEY set)

Proposed role assignments:
  test:           claude                            (strong executor for quality tests)
  implementation: aider-local-qwen → claude          (local first, escalate if stuck)
  scaffold:       claude                             (capable of large scaffold tasks)

Confirm these assignments, or adjust?
```

If only Aider with a local model is available:

```
Proposed role assignments:
  test:           aider-local-qwen                  (no other executors available)
  implementation: aider-local-qwen                  (no escalation — single tier)
  scaffold:       aider-local-qwen

Note: Only one executor detected. Escalation is disabled.
Install `claude` or `gemini` CLI to enable escalation.
```

## Presentation

Present the analysis as a structured summary:

```
## Pipeline Analysis: <feature-name>

### Tasks
- Total: N tasks (T test + I implementation)
- Phases: scaffold (S), core (C), integration (I), testing (T), infrastructure (F)
- Dependency depth: D

### Working Directory
- Service root: `services/my-service/`
- Scaffold tasks: run from project root
- Other tasks: run from service root

### Detected Tooling
- Ecosystem: Python + uv
- Lint: `uv run ruff check`
- Lint auto-fix: `uv run ruff check --fix`
- Test: `uv run pytest`
- Bootstrap: `uv sync` (after task-01)

### Executor Configuration
<proposed executor and role assignment — see above>

### Per-Task Summary
| Task ID | Type | Role | Executor (default) | Test Command | Verification |
|---------|------|------|--------------------|--------------|--------------|
| task-01 | impl | scaffold | claude | (none) | scaffold |
| task-02 | test | test | claude | `uv run pytest tests/test_x.py -x` | expect failure |
| task-03 | impl | implementation | aider-local-qwen | `uv run pytest tests/test_x.py -x` | expect pass |
| ... | | | | | |

### Prerequisites
- [✓/✗] Aider CLI installed
- [✓/✗] Claude CLI installed and authenticated
- [✓/✗] Gemini CLI installed and authenticated
- [✓/✗] LM Studio reachable (if using Aider with local models)
- [✓/✗] Lint command verified
- [✓/✗] Lint auto-fix verified
```

Ask the user to confirm executor assignments and detected commands before
proceeding.
