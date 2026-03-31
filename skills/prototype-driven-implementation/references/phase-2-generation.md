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
│   ├── bootstrap.py           # Tooling environment initialization
│   └── report.py              # Final summary
├── aider_bridge.py            # Aider subprocess wrapper
├── requirements.txt           # langgraph, pydantic
└── README.md                  # Usage instructions
```

## File-by-File Generation Guide

### `config.py`

Single place for all configurable values. Generated from Phase 1 detection.

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
# Service root: the directory where lint/test tools are installed.
# Most tasks use this as their Aider cwd.
SERVICE_ROOT = PROJECT_ROOT / "<detected-service-subdir>"

# Per-task working directory overrides.
# Scaffold tasks automatically use PROJECT_ROOT (service dir may not exist).
# Override here for other special cases.
TASK_WORKING_DIRS: dict[str, str] = {}

# ── Scaffold Bootstrap ────────────────────────────────────────
# After the scaffold task creates the project config file, the pipeline
# runs this command to initialize the tooling environment (install deps,
# make lint/test tools available). Without this, subsequent tasks cannot
# run lint or tests.
BOOTSTRAP_AFTER_TASK = "<scaffold-task-id>"   # e.g., "task-01"
BOOTSTRAP_COMMAND = "<detected-bootstrap>"    # e.g., "uv sync", "npm install"
BOOTSTRAP_WORKING_DIR = str(SERVICE_ROOT)

# ── Model ──────────────────────────────────────────────────────
MODEL_TIERS = [
    {
        "name": "local",
        "model": "<detected-model-string>",
        "api_base": "http://localhost:1234/v1",
        "api_key": "lm-studio",
    },
]

# ── Retry Limits ───────────────────────────────────────────────
MAX_RETRIES_PER_TASK = 3

# ── Tooling ────────────────────────────────────────────────────
# Bare tool names that work from the service root directory.
DEFAULT_LINT_CMD = "<detected-lint-command>"  # e.g., "ruff check"
TEST_RUNNER = "<detected-test-runner>"        # e.g., "pytest"
GLOBAL_TEST_CMD = "<detected-global-test-command>"

# Per-task test commands (paths relative to task's working dir).
TASK_TEST_COMMANDS: dict[str, str | None] = {}

# Per-task lint overrides. None = skip lint for that task.
TASK_LINT_OVERRIDES: dict[str, str | None] = {}

# ── Aider ──────────────────────────────────────────────────────
AIDER_EXTRA_ARGS = [
    "--no-show-model-warnings",
    "--no-check-update",
    "--no-git",
    "--yes-always",
]
```

Fill in all placeholder values from Phase 1. Use absolute paths for
`PROJECT_ROOT` and `SERVICE_ROOT`.

### Scaffold Tasks and Working Directory

Scaffold tasks create the service directory itself — they can't run from a
directory that doesn't exist yet. The `aider_bridge.get_task_working_dir()`
function handles this automatically:

```python
def get_task_working_dir(task_id: str) -> str:
    """Determine working directory for a task.

    Scaffold tasks run from project root (service dir may not exist yet).
    All other tasks run from service root (where tools are installed).
    """
    if task_id in config.TASK_WORKING_DIRS:
        return config.TASK_WORKING_DIRS[task_id]

    # Scaffold tasks: check phase from the loaded tasks
    task = _find_task_by_id(task_id)
    if task and task.get("phase") == "scaffold":
        return str(config.PROJECT_ROOT)

    return str(config.SERVICE_ROOT)
```

For scaffold tasks running from the project root:
- File paths are NOT rebased (they're already project-root-relative)
- Lint is typically skipped (tools aren't installed yet)
- No test gate

After the scaffold task passes, the `bootstrap` node runs the environment
initialization command, making tools available for all subsequent tasks.

### Path Rebasing

For non-scaffold tasks, file paths from tasks.json (project-root-relative)
must be rebased to be relative to the service root:

```
SERVICE_ROOT = PROJECT_ROOT / "services/airflow-ingestion"
task file:    "services/airflow-ingestion/plugins/client.py"  (tasks.json)
rebased:      "plugins/client.py"                              (for --file)
aider cwd:    /abs/path/services/airflow-ingestion/
```

The `verify_task` node uses the same working directory for lint/test commands.

### Environment Isolation

Strip the pipeline's own venv from subprocess environments:

```python
env = os.environ.copy()
for var in ("VIRTUAL_ENV", "VIRTUAL_ENV_PROMPT"):
    env.pop(var, None)
```

This prevents the pipeline's langgraph/pydantic venv from shadowing the
service's tooling. Applies to any language ecosystem that uses environment
variables for tool resolution.

### `pipeline_state.py`

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
    all_tasks: list[dict]
    task_order: list[str]
    feature_name: str

    # Execution loop
    current_task_id: str | None
    current_retry: int
    task_results: dict[str, TaskResult]

    # Prompt management
    current_prompt_path: str | None

    # Error context for retry prompts
    current_lint_errors: str
    current_test_errors: str

    # Bootstrap tracking
    bootstrap_done: bool

    # Terminal state
    is_complete: bool
    summary: str
```

### `graph.py`

See `references/langgraph-patterns.md` for the full graph structure including
the bootstrap node.

### `nodes/load_tasks.py`

Reads `tasks.json`, validates against the schema, produces topological order.
Import the schema from `tasks/<feature>/task_schema.py` by adding the tasks
directory to `sys.path`. Use the schema's `tasks_in_order()` method.

### `nodes/compose_prompt.py`

Transforms task JSON into a self-contained markdown message file for Aider.
See `references/aider-integration.md` § "Prompt Template" for the format.

For scaffold tasks (cwd = project root), use the original project-root-relative
file paths. For all other tasks (cwd = service root), use rebased paths.

### `nodes/execute_task.py`

Invokes Aider via `aider_bridge`. Does NOT verify — that's `verify_task`.

### `nodes/verify_task.py`

Independent lint/test verification using the same working directory as Aider.
Catches reflection exhaustion (Aider exits 0 but tests still fail).

### `nodes/bootstrap.py`

Runs the tooling bootstrap command after the scaffold task. Triggered once,
tracked via `bootstrap_done` in state. See `references/langgraph-patterns.md`
§ "Scaffold Tasks and Working Directory" for the implementation.

### `nodes/report.py`

Final summary with pass/fail/skip/degraded counts. Runs `GLOBAL_TEST_CMD`
as a final sanity check.

### `aider_bridge.py`

Subprocess wrapper. Key functions: `get_task_working_dir()`, `rebase_path()`,
`build_command()`, `run_aider()`, `run_verification()`,
`detect_reflection_exhaustion()`. See `references/aider-integration.md` for
the full implementation.

### `run.py`

Entry point with CLI argument parsing:

```python
"""Run the implementation pipeline.

Usage:
    python run.py                    # Run all tasks
    python run.py --start task-05    # Resume from task-05
    python run.py --model <string>   # Override the model
    python run.py --max-retries 5    # Override retry limit
"""
```

Supports:
- `--start <task-id>` — skip tasks before this ID (for resuming after fixes)
- `--model <model-string>` — override the model from config
- `--max-retries <N>` — override retry limit

No `--dry-run` flag. A dry-run that skips real execution creates false
confidence. Phase 3 validates the pipeline through precondition checks instead.

### `requirements.txt`

```
langgraph>=0.2.0
pydantic>=2.0.0
```

### `README.md`

Feature-specific README with prerequisites, run commands, config reference,
and troubleshooting.

## Generation Principles

- **Generate concrete code, not templates.** Fill in all config values from
  Phase 1. No placeholders in the runnable code.

- **Import the task schema, don't reinvent it.** Use `task_schema.py` from
  the tasks directory.

- **Keep nodes focused.** One responsibility per node. Clean boundaries
  enable v2 escalation as a localized graph change.

- **Log everything.** Timestamped log file at
  `pipelines/<feature>/logs/run-<timestamp>.log` with full Aider output,
  verification results, and state transitions.

- **Run without interruption.** Scaffold → bootstrap → execute is seamless.
  The user starts the pipeline and walks away. Intervention is only needed
  when tasks exhaust retries.
