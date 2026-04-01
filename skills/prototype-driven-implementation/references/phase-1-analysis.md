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

This is the single most important detection step. Aider runs lint and test
commands as subprocess calls from whatever `cwd` it's given. Lint tools and
test runners are typically installed local to a service or package directory —
not globally. If the tools aren't on PATH from the working directory, every
lint and test invocation will fail with "command not found."

Additionally, Aider appends edited filenames as paths relative to its cwd to
the lint command. This is a documented Aider behavior that the pipeline must
account for (see Aider issue #1579 for monorepo context).

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
no activated environment.** Aider and the pipeline run tools via
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

**Detection steps:**

1. Identify the language ecosystem from the service root's config files
2. Determine the tool runner for that ecosystem (see table above)
3. Identify the specific lint tool and test framework configured
4. Compose the full command: `<runner> <tool> <args>`

For example, a Python project using uv with ruff and pytest:
- Detect: `pyproject.toml` with `[tool.ruff]` and `[tool.pytest.ini_options]`
- Detect: `uv.lock` exists → this is a uv-managed project
- Lint command: `uv run ruff check` (not `ruff check`)
- Test command: `uv run pytest <files> -x` (not `pytest <files> -x`)

**Verification:** After detection, actually run the lint command from the
service root on an existing file to confirm it works. If the service root
doesn't exist yet (scaffold hasn't run), verify against the prototype
directory instead — the prototype has the same tooling config.

```bash
cd prototypes/<feature>/
uv run ruff check --version  # Should print ruff version, not "not found"
```

### Auto-Fix Detection

Check whether the detected linter supports an auto-fix mode. The design doc's
Tooling section (produced by the planning skill) records this, but verify it
independently in case the design doc was written before auto-fix discovery was
added.

**Check the design doc first.** Read the `## Tooling` section of the design
doc at `docs/design/<feature>.md`. If it contains an `Auto-fix command` field,
use that value. If the Tooling section is missing or doesn't mention auto-fix,
detect it manually.

**Manual detection by ecosystem:**

| Ecosystem | Linter | Auto-fix command | Verify with |
|-----------|--------|------------------|-------------|
| Python | ruff | `uv run ruff check --fix` | Unsort an import, run fix, check it resolves |
| TypeScript/JS | eslint | `npx eslint --fix` | Add trailing comma style error, run fix |
| Rust | clippy | `cargo clippy --fix` | Introduce a clippy-fixable pattern |
| Go | goimports | `goimports -w` | Unsort imports, run, verify |
| Kotlin | ktlint | `ktlint -F` | Introduce import ordering error |

**Verification:** If possible, run the auto-fix command against a prototype
file to confirm it works. If the prototype directory doesn't have a fixable
error, intentionally introduce one (e.g., unsort an import block), run auto-fix,
and confirm it resolves cleanly.

Record the result:
- If auto-fix works: `DEFAULT_LINT_FIX_CMD = "<detected command>"`
- If auto-fix is not available or unreliable: `DEFAULT_LINT_FIX_CMD = None`

### Per-Task Working Directory

Most tasks share the service root as their working directory. But some tasks
(infrastructure, deployment) may create files outside the service tree.

For each task, determine the working directory:
1. If `phase == "scaffold"` → cwd = project root (service dir doesn't exist yet)
2. If all files share the service root prefix → cwd = service root
3. If files are outside the service tree → cwd = project root or a custom dir

Store overrides in `TASK_WORKING_DIRS: dict[str, str]`. Tasks not listed use
the service root by default (scaffold tasks are handled automatically by the
pipeline's `get_task_working_dir()` function).

### File Path Rebasing

File paths from `tasks.json` are relative to the project root. For tasks
running from the service root, these must be rebased:

```
project root:    /Users/me/my-project/
service root:    /Users/me/my-project/services/my-service/
task file path:  services/my-service/plugins/client.py    (from tasks.json)
rebased path:    plugins/client.py                         (for --file arg)
aider cwd:       /Users/me/my-project/services/my-service/
```

Scaffold tasks run from the project root, so no rebasing is needed for them.

## Per-Task Test Command Derivation

For each task, compose the test command using the detected runner pattern
and the task's test file paths (rebased to the working directory):

### Test tasks (`task_type: "test"`)

Test tasks write test files. Their verification is special:
- The test file must be syntactically valid (importable)
- The tests must FAIL (no implementation exists yet)

Command: `<runner> <framework> <rebased_test_file> -x`

Example (uv + pytest): `uv run pytest tests/test_client.py -x`

For test tasks, do NOT use Aider's `--auto-test` — it expects tests to pass,
which would cause an infinite fix loop. Use `--auto-lint` only. The pipeline's
`verify_task` node handles the inverted check independently.

### Implementation tasks (`task_type: "implementation"`)

Implementation tasks write production code. Their verification:
- All previously-written tests must PASS
- Lint must pass

Command: `<runner> <framework> <rebased_test_file_1> <rebased_test_file_2> -x`

For implementation tasks, use both Aider's `--auto-lint` and `--auto-test`.

### Tasks with no tests

Scaffold, config, and infrastructure tasks with empty `tests` lists get
`--auto-lint` only. No test gate.

## Bootstrap Detection

Look at the scaffold-phase tasks. If any task creates a project config file
(`pyproject.toml`, `package.json`, `build.gradle`), the pipeline needs a
bootstrap step after that task to initialize the tooling environment.

Determine the bootstrap command from the ecosystem:

| Config file created | Bootstrap command |
|-------------------|------------------|
| `pyproject.toml` + uv | `uv sync` |
| `pyproject.toml` + pip | `pip install -e ".[dev]"` |
| `package.json` + npm | `npm install` |
| `package.json` + yarn | `yarn install` |
| `build.gradle` | `./gradlew build` |
| `Cargo.toml` | `cargo build` |

## Model Detection and Role Assignment

### Detect Available Models

Check LM Studio for locally available models:

```bash
curl -s http://localhost:1234/v1/models
```

If reachable, extract the loaded model name(s). If not reachable, note as a
prerequisite.

### Check for Cloud Model API Keys

For each cloud model the user might want to use, check whether the required
environment variable is set:

```bash
# Anthropic (Claude)
[ -n "$ANTHROPIC_API_KEY" ] && echo "Anthropic API key: set" || echo "Anthropic API key: NOT SET"

# OpenAI
[ -n "$OPENAI_API_KEY" ] && echo "OpenAI API key: set" || echo "OpenAI API key: NOT SET"
```

Do not display the key values — only whether they are set.

### Propose Model Configuration

Present the detected models and ask the user to confirm role assignments. The
pipeline uses three roles:

- **test** — writes test files. Benefits from a strong model that produces
  real assertions and proper mock setups rather than `NotImplementedError`
  stubs. Test quality directly determines whether implementation tasks have
  meaningful guardrails.
- **implementation** — writes production code constrained by pre-written tests.
  Local models work well here because the tests provide tight feedback.
- **scaffold** — creates project structure, config files, boilerplate. Low
  complexity, local models are sufficient.

Each role maps to an ordered list of model names. The first model in the list
is the default; subsequent entries are escalation tiers tried when the default
exhausts its retries.

Present the proposal like this:

```
### Model Configuration

Detected models:
  local-qwen:  lm_studio/qwen/qwen3-coder-30b (LM Studio, localhost:1234)
  sonnet:      anthropic/claude-sonnet-4 (ANTHROPIC_API_KEY is set)

Proposed role assignments:
  test:           sonnet                    (strong model for quality tests)
  implementation: local-qwen → sonnet       (local first, escalate if stuck)
  scaffold:       local-qwen                (boilerplate, no escalation needed)

Confirm these assignments, or adjust?
```

If only a local model is available (no cloud API keys set), assign it to all
roles. Note in the output that model escalation won't be available:

```
Proposed role assignments:
  test:           local-qwen                (no cloud model available)
  implementation: local-qwen                (no escalation — single tier)
  scaffold:       local-qwen

Note: No cloud API keys detected. All roles use the local model.
Model escalation (retrying with a stronger model) is disabled.
Set ANTHROPIC_API_KEY to enable escalation.
```

## Aider Availability Check

```bash
which aider && aider --version
```

If not found: `pip install aider-chat` or `uv tool install aider-chat`.

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

### Model Configuration
<proposed model and role assignment — see above>

### Per-Task Summary
| Task ID | Type | Role | Lint | Test Command | Verification |
|---------|------|------|------|--------------|--------------|
| task-01 | impl | scaffold | (skip) | (none) | scaffold |
| task-02 | impl | implementation | uv run ruff check | (none) | lint only |
| task-03 | test | test | uv run ruff check | `uv run pytest tests/test_x.py -x` | expect failure |
| task-04 | impl | implementation | uv run ruff check | `uv run pytest tests/test_x.py -x` | expect pass |
| ... | | | | | |

### Prerequisites
- [✓/✗] Aider installed
- [✓/✗] LM Studio reachable
- [✓/✗] Cloud API keys (if using cloud models)
- [✓/✗] Lint command verified against prototype
- [✓/✗] Lint auto-fix verified
```

Ask the user to confirm detected commands, model assignments, and ecosystem
before proceeding.
