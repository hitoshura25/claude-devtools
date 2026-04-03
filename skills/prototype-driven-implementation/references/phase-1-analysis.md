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

Executor detection has three sub-steps: discover which CLIs are installed,
research their non-interactive invocation patterns, and verify each works
with a test prompt. All three must pass before proceeding to Phase 2.

### Step 1: Discover Available CLIs

Check which coding agent CLIs are on PATH:

```bash
which aider && aider --version
which claude && claude --version
which gemini && gemini --version
```

For Aider, also check model backends:

```bash
# LM Studio local models
curl -s http://localhost:1234/v1/models

# Cloud API keys for Aider backends
[ -n "$GEMINI_API_KEY" ] && echo "Gemini API key: set"
[ -n "$ANTHROPIC_API_KEY" ] && echo "Anthropic API key: set"
```

### Step 2: Research Non-Interactive Invocation Patterns

For each detected CLI (other than Aider, whose patterns are well-established),
**search the web for the CLI's official documentation** on headless /
non-interactive / print mode. This research determines the exact command
the generated pipeline will use to invoke the executor.

**Why research rather than hardcode:** CLI tools update their flags and
conventions. Hardcoding patterns in the skill reference means they go stale.
Researching the docs at pipeline-generation time ensures the generated
`agent_bridge.py` uses the current, correct invocation.

For each CLI, find answers to these questions:

1. **Non-interactive flag**: What flag runs the CLI in non-interactive mode
   where it processes a prompt and exits? (e.g., `-p`, `--print`, `--headless`)

2. **Prompt delivery**: How is the prompt passed? As a positional argument,
   via stdin, or via a file path flag? For long prompts (our task prompts are
   often 2000+ chars), which method avoids shell argument length limits?

3. **Tool permissions in headless mode**: In non-interactive mode, how does
   the CLI handle tool approvals (file writes, shell commands)? What flags
   are needed to pre-approve the tools the pipeline needs (file read, file
   write/create, file edit, shell commands)? This is critical — if the CLI
   prompts for permission in headless mode, the subprocess will hang.

4. **Model selection**: How is a specific model variant selected?
   (e.g., `--model opus`, `-m gemini-2.5-flash`)

5. **Turn/iteration limits**: Is there a flag to limit the number of
   autonomous turns? This prevents runaway loops.

6. **Subprocess compatibility**: Are there known issues with the CLI when
   spawned as a subprocess (e.g., stdin handling, TTY detection, hanging)?
   Check the CLI's issue tracker and changelog for relevant fixes.

**Search queries to use** (adapt to the specific CLI):

- For Claude CLI: search for "claude code CLI headless mode" or "claude code
  -p print mode documentation" and look at the official docs at
  `code.claude.com/docs/en/headless`
- For Gemini CLI: search for "gemini CLI headless mode" or "gemini CLI
  non-interactive" and look at the official docs at
  `google-gemini.github.io/gemini-cli/docs/cli/headless.html`

Record the researched patterns. For each CLI, document:

```
Executor: claude
  Non-interactive flag: <researched>
  Prompt delivery: <researched — argument vs stdin vs file>
  Tool permissions: <researched — exact flags needed for headless file/shell ops>
  Model selection: <researched — flag and value format>
  Turn limit: <researched — flag if available>
  Known subprocess issues: <researched — any gotchas>
  Full test command: <composed from above>
```

### Step 3: Verify Executor Communication

For each detected and researched CLI, run a minimal test prompt using the
researched invocation pattern. This proves the command actually works as a
subprocess before the pipeline is generated.

The test prompt should be simple and quick:

```
Reply with exactly the word: OK
```

Run it using the full command pattern from Step 2 (including the tool
permission flags, stdin piping, etc. — exactly as the pipeline would invoke
it). Capture stdout, stderr, and return code.

**Pass criteria:**
- Return code is 0
- stdout contains some response (doesn't need to be exactly "OK" — the point
  is that the CLI processed the prompt and returned)
- The command completes within 30 seconds (a hang means the permission
  flags are wrong)

**If the test fails:**
- Return code non-zero → check stderr for auth errors, model not found, etc.
- Timeout/hang → the tool permission flags are likely wrong, research again
  specifically for how to avoid permission prompts in non-interactive mode
- Command not found → the CLI is not on PATH despite `which` succeeding
  (possible venv issue)

Report the test result to the user and include the exact command that was
tested. If it fails, stop and troubleshoot before proceeding.

### Step 4: Propose Executor Configuration

Present the detected, researched, and verified executors with their invocation
patterns and propose role assignments.

```
### Executor Configuration

Detected and verified executors:
  aider-local-qwen:   aider + lm_studio/qwen/qwen3-coder-30b (localhost:1234)
    Invocation: aider --message-file <prompt> --file <files...> [well-known]
    Test: PASSED

  claude:             claude CLI (Pro plan)
    Invocation: <researched command pattern>
    Test: PASSED (response received in Xs)

  gemini-flash:       gemini CLI + gemini-2.5-flash
    Invocation: <researched command pattern>
    Test: PASSED (response received in Xs)

Proposed role assignments:
  test:           claude
  implementation: aider-local-qwen → claude
  scaffold:       claude

Confirm these assignments, or adjust?
```

The verified invocation patterns are stored in the executor config and used
by Phase 2 to generate the `agent_bridge.py` command construction functions.

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
<detected, researched, and verified executors with role assignments — see above>

### Per-Task Summary
| Task ID | Type | Role | Executor (default) | Test Command | Verification |
|---------|------|------|--------------------|--------------|--------------|
| task-01 | impl | scaffold | claude | (none) | scaffold |
| task-02 | test | test | claude | `uv run pytest tests/test_x.py -x` | expect failure |
| task-03 | impl | implementation | aider-local-qwen | `uv run pytest tests/test_x.py -x` | expect pass |
| ... | | | | | |

### Prerequisites
- [✓/✗] Aider CLI installed and verified
- [✓/✗] Claude CLI installed, researched, and verified
- [✓/✗] Gemini CLI installed, researched, and verified
- [✓/✗] LM Studio reachable (if using Aider with local models)
- [✓/✗] Lint command verified
- [✓/✗] Lint auto-fix verified
```

Ask the user to confirm executor assignments and detected commands before
proceeding.
