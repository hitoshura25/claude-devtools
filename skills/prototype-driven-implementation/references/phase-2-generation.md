# Phase 2: Pipeline Generation — Detailed Guidance

## Output Structure

Generate the pipeline at `pipelines/<feature-name>/`:

```
pipelines/<feature-name>/
├── run.py                     # Entry point with CLI
├── config.py                  # All configuration in one place
├── pipeline_state.py          # LangGraph TypedDict state
├── graph.py                   # StateGraph definition
├── nodes/
│   ├── __init__.py
│   ├── load_tasks.py          # Read + validate tasks.json
│   ├── compose_prompt.py      # Build message file for Aider
│   ├── execute_task.py        # Invoke Aider subprocess
│   ├── verify_task.py         # Independent lint/test verification
│   └── report.py              # Final summary
├── aider_bridge.py            # Aider subprocess wrapper
├── requirements.txt           # langgraph, pydantic
└── README.md                  # Usage instructions
```

## File-by-File Generation Guide

### `config.py`

This file is the single place for all configurable values. Generate it from
what Phase 1 detected.

```python
"""Pipeline configuration — all settings in one place.

Edit this file to change model endpoints, retry limits, or tooling commands.
These values were detected from the project during pipeline generation.
"""
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────
PROJECT_ROOT = Path("<absolute-path-to-project-root>")
TASKS_DIR = PROJECT_ROOT / "tasks" / "<feature-name>"
TASKS_JSON = TASKS_DIR / "tasks.json"
TASK_SCHEMA = TASKS_DIR / "task_schema.py"
PROTOTYPE_DIR = PROJECT_ROOT / "prototypes" / "<feature-name>"
PIPELINE_DIR = Path(__file__).parent

# ── Working Directories ───────────────────────────────────────
# Service root: the directory where lint/test tools are installed and
# commands should run from. Detected from the common file path prefix
# in tasks.json. Most tasks use this as their Aider cwd.
SERVICE_ROOT = PROJECT_ROOT / "<detected-service-subdir>"

# Per-task working directory overrides. Maps task ID to an absolute path.
# Tasks not listed here use SERVICE_ROOT.
# Infrastructure/deployment tasks often need the project root instead.
TASK_WORKING_DIRS: dict[str, str] = {
    # "task-26": str(PROJECT_ROOT),  # Dockerfile at project root
}

# ── Model ──────────────────────────────────────────────────────
# Model tiers for escalation. v1 uses only the first tier.
# v2 will add cloud fallback tiers here.
MODEL_TIERS = [
    {
        "name": "local",
        "model": "<detected-model-string>",
        "api_base": "http://localhost:1234/v1",
        "api_key": "lm-studio",
    },
]

# ── Retry Limits ───────────────────────────────────────────────
MAX_RETRIES_PER_TASK = 3  # Circuit breaker: mark as failed after this many

# ── Tooling ────────────────────────────────────────────────────
# Lint and test commands run from the task's working directory.
# They should be bare tool names that work from that directory —
# the pipeline sets Aider's cwd to the working directory so
# locally-installed tools are naturally on PATH.
DEFAULT_LINT_CMD = "<detected-lint-command>"  # e.g., "ruff check"
TEST_RUNNER = "<detected-test-runner>"        # e.g., "pytest"
GLOBAL_TEST_CMD = "<detected-global-test-command>"  # full suite

# Per-task test commands. File paths are relative to the task's
# working directory (after rebasing from project-root-relative).
# None means no test gate for this task.
TASK_TEST_COMMANDS: dict[str, str | None] = {
    # Generated from Phase 1 analysis
}

# Per-task lint command overrides. None means skip lint.
TASK_LINT_OVERRIDES: dict[str, str | None] = {
    # Infrastructure tasks may skip lint or use a different linter
}

# ── Aider ──────────────────────────────────────────────────────
AIDER_EXTRA_ARGS = [
    "--no-show-model-warnings",
    "--no-check-update",
    "--no-git",
    "--yes-always",
]
```

Fill in the placeholder values from Phase 1 detection. Use absolute paths for
`PROJECT_ROOT` and `SERVICE_ROOT` so the pipeline can run from any working
directory.

### Working Directory and Path Rebasing

The critical pattern: Aider's cwd determines where lint/test tools are found
and how file paths are interpreted. The pipeline must rebase file paths from
`tasks.json` (which are relative to project root) to be relative to the task's
working directory.

The `aider_bridge.py` module handles this rebasing. For each task:
1. Determine the working directory (from `TASK_WORKING_DIRS` or default `SERVICE_ROOT`)
2. For each file in the task's `files` list, strip the working directory
   prefix (relative to project root) to get the path relative to the cwd
3. Pass the rebased paths as `--file` arguments to Aider
4. Rebase test file paths the same way for `--test-cmd`

Example:
```
SERVICE_ROOT = PROJECT_ROOT / "services/airflow-ingestion"
task file:    "services/airflow-ingestion/plugins/client.py"  (from tasks.json)
service prefix: "services/airflow-ingestion/"
rebased:       "plugins/client.py"                            (for --file)
aider cwd:     /abs/path/services/airflow-ingestion/
```

The `verify_task` node also uses the same working directory when running
lint and test commands independently after Aider finishes.

### Environment Isolation

The pipeline itself may run in its own virtual environment (for langgraph,
pydantic). To prevent this environment from leaking into Aider and verification
subprocesses, the `aider_bridge.py` should strip environment variables that
could cause confusion:

```python
env = os.environ.copy()
# Remove pipeline's own venv to prevent it from shadowing
# the service's tooling installation
for var in ("VIRTUAL_ENV", "VIRTUAL_ENV_PROMPT"):
    env.pop(var, None)
```

This is not Python-specific — any language ecosystem that uses environment
variables for tool resolution (e.g., `NODE_PATH`, `GOPATH`) may need similar
treatment. The principle: the subprocess should see the service directory's
tooling environment, not the pipeline's.

### `pipeline_state.py`

The LangGraph state that flows through the graph. Every node reads from and
writes to this shared state.

```python
"""Pipeline state — the data that flows through the LangGraph graph."""
from typing import TypedDict

class TaskResult(TypedDict):
    task_id: str
    status: str         # "passed", "failed", "skipped", "degraded"
    retries: int
    lint_passed: bool
    test_passed: bool | None  # None if no test gate
    error_summary: str  # empty if passed

class PipelineState(TypedDict):
    # Set by load_tasks
    all_tasks: list[dict]              # Raw task dicts from tasks.json
    task_order: list[str]              # Task IDs in topological order
    feature_name: str

    # Managed by the execution loop
    current_task_id: str | None        # ID of task being executed
    current_retry: int                 # Retry count for current task
    task_results: dict[str, TaskResult]  # task_id -> result

    # Prompt file management
    current_prompt_path: str | None    # Path to current message file

    # Terminal state
    is_complete: bool
    summary: str                       # Final report text
```

### `graph.py`

The StateGraph definition. See `references/langgraph-patterns.md` for the
full graph structure. The key design: a loop that picks the next unprocessed
task, executes it via Aider, verifies the result, and either advances or retries.

### `nodes/load_tasks.py`

Reads `tasks.json`, validates against the schema, and produces the topological
execution order. Sets `all_tasks` and `task_order` in state.

Key implementation detail: import the schema from `tasks/<feature>/task_schema.py`
by adding the tasks directory to `sys.path`. Use the schema's `tasks_in_order()`
method for topological sorting — don't reimplement it.

### `nodes/compose_prompt.py`

This is the most important node. It transforms a task's JSON definition into
a self-contained markdown message file that Aider receives via `--message-file`.

The prompt must include everything the implementing model needs:
1. **Task description** — from the task's `description` field
2. **Files to create** — from `files`, with operation (create/modify) and
   descriptions. Use the **rebased** paths (relative to the task's working
   directory) so the model sees the same paths Aider is using.
3. **Inlined prototype references** — for each entry in `prototype_references`,
   read the referenced file from the prototype directory and extract the relevant
   section. Include the actual code, not just a pointer.
4. **Acceptance criteria** — from `acceptance_criteria`
5. **Security considerations** — from `security_considerations` (if any)
6. **Output constraint** — tell the model to respond with only file changes

See `references/aider-integration.md` § "Prompt Template" for the exact format.

### `nodes/execute_task.py`

Invokes Aider via the `aider_bridge.py` wrapper. Reads the current task from
state, gets the Aider arguments from `aider_bridge.build_command()`, and runs
the subprocess. Captures stdout/stderr for logging.

This node does NOT verify results — it only runs Aider and captures its exit
code. Verification is a separate node so the graph structure is clean.

### `nodes/verify_task.py`

Runs lint and test commands independently after Aider finishes. This catches
silent failures (Aider reflection exhaustion exits 0 even when tests fail).

**Important:** Verification commands must run from the same working directory
as Aider used for that task. Use the same cwd resolution logic.

Logic:
1. Run lint command from the task's working directory. If it fails, mark
   lint_passed = False.
2. If the task has a test command:
   - For implementation tasks: run the test command, expect exit 0.
   - For test tasks: run the test command, expect non-zero exit (tests should
     fail because implementation doesn't exist yet).
3. Update `task_results` in state based on outcomes.

### `nodes/report.py`

Generates the final summary after all tasks are processed. Includes:
- Count of passed, failed, skipped, degraded tasks
- Per-task status table
- Failed task details (error summary, retry count)
- Whether the global test suite passes (run `GLOBAL_TEST_CMD` as final check)

### `aider_bridge.py`

Subprocess wrapper that builds and executes the Aider CLI command. Separated
from the node so it can be tested independently.

Key responsibilities:
1. **Rebase file paths** from project-root-relative to cwd-relative
2. **Build the Aider command** with rebased paths
3. **Run the subprocess** with the correct cwd and clean environment
4. **Detect reflection exhaustion** from Aider output

```python
def get_task_working_dir(task_id: str) -> str:
    """Return the absolute working directory for a task."""
    override = config.TASK_WORKING_DIRS.get(task_id)
    if override:
        return override
    return str(config.SERVICE_ROOT)

def rebase_path(file_path: str, working_dir: str) -> str:
    """Rebase a project-root-relative path to be relative to working_dir.

    Example:
        file_path:   "services/my-service/plugins/client.py"
        working_dir: "/abs/path/services/my-service"
        project_root: "/abs/path"
        service_prefix: "services/my-service/"
        result:      "plugins/client.py"
    """
    project_root = str(config.PROJECT_ROOT)
    abs_file = os.path.join(project_root, file_path)
    return os.path.relpath(abs_file, working_dir)

def build_command(
    task: dict,
    message_file_path: str,
    model_tier: dict,
    lint_cmd: str | None,
    test_cmd: str | None,
    working_dir: str,
    extra_args: list[str],
) -> list[str]:
    """Build the aider CLI command with rebased file paths."""
    cmd = [
        "aider",
        "--model", model_tier["model"],
        "--openai-api-base", model_tier["api_base"],
        "--openai-api-key", model_tier["api_key"],
        "--message-file", message_file_path,
    ]

    # Files: rebase from project-root-relative to cwd-relative
    for f in task.get("files", []):
        rebased = rebase_path(f["path"], working_dir)
        cmd.extend(["--file", rebased])

    # Lint
    if lint_cmd:
        cmd.extend(["--lint-cmd", lint_cmd, "--auto-lint"])

    # Test (implementation tasks only)
    if test_cmd and task.get("task_type") == "implementation":
        cmd.extend(["--test-cmd", test_cmd, "--auto-test"])

    cmd.extend(extra_args)
    return cmd
```

Note: Aider's `--model` flag for LM Studio uses the format
`openai/<model-name>` with `--openai-api-base` pointing to the LM Studio
endpoint. The exact format depends on the Aider version, so also support
the `lm_studio/<model-name>` format seen in the agent-ready-plans skill.

### `run.py`

Entry point with CLI argument parsing:

```python
"""Run the implementation pipeline.

Usage:
    python run.py                    # Run all tasks
    python run.py --start task-05    # Resume from task-05
    python run.py --dry-run          # Walk the graph without invoking Aider
    python run.py --model <string>   # Override the model
"""
```

Supports:
- `--start <task-id>` — skip tasks before this ID (for resuming)
- `--dry-run` — walk the graph, print what would execute, don't invoke Aider
- `--model <model-string>` — override the model from config
- `--max-retries <N>` — override retry limit

### `requirements.txt`

```
langgraph>=0.2.0
pydantic>=2.0.0
```

The pipeline should work with these minimal dependencies. LangGraph pulls in
langchain-core, but the pipeline doesn't use LangChain models — it uses Aider
as the execution backend.

### `README.md`

Generate a README specific to this feature's pipeline. Include:
- What the pipeline does
- Prerequisites (Aider, LM Studio, model loaded)
- How to install dependencies
- How to run (all tasks, resume, dry-run)
- How to read results
- Configuration reference (what each config.py value does)
- Troubleshooting (common failures and fixes)

## Generation Principles

- **Generate concrete code, not templates.** The pipeline files should be
  runnable Python, not templates with placeholders. Fill in all config values
  from Phase 1 detection.

- **Match the project's Python style.** If the project uses type hints,
  f-strings, pathlib — match that in the pipeline code. If it's more
  conservative, match that.

- **Import the task schema, don't reinvent it.** The pipeline's `load_tasks.py`
  imports from `task_schema.py` in the tasks directory. Don't redefine task
  models in the pipeline.

- **Keep nodes focused.** Each node does one thing. `execute_task` runs Aider.
  `verify_task` checks results. Don't merge them — the graph structure needs
  clean node boundaries for v2 escalation.

- **Log everything.** The pipeline should produce a timestamped log file at
  `pipelines/<feature>/logs/run-<timestamp>.log` with full Aider output,
  verification results, and state transitions.
