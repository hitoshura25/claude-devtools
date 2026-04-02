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
│   ├── compose_prompt.py      # Build prompt content for executors
│   ├── execute_task.py        # Dispatch to the appropriate executor
│   ├── verify_task.py         # Auto-fix + independent lint/test verification
│   ├── bootstrap.py           # Tooling environment initialization
│   └── report.py              # Final summary
├── agent_bridge.py            # Executor dispatch and subprocess wrappers
├── requirements.txt           # langgraph, pydantic
└── README.md                  # Usage instructions
```

## File-by-File Generation Guide

### `config.py`

Single place for all configurable values. Generated from Phase 1 detection.

```python
"""Pipeline configuration — all settings in one place.

Edit this file to change executors, retry limits, or tooling commands.
These values were detected from the project during pipeline generation.
"""
import os
import shutil
import sys
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────
PROJECT_ROOT = Path("<absolute-path-to-project-root>")
TASKS_DIR = PROJECT_ROOT / "tasks" / "<feature-name>"
TASKS_JSON = TASKS_DIR / "tasks.json"
TASK_SCHEMA = TASKS_DIR / "task_schema.py"
PROTOTYPE_DIR = PROJECT_ROOT / "prototypes" / "<feature-name>"
PIPELINE_DIR = Path(__file__).parent

# ── Working Directories ───────────────────────────────────────
SERVICE_ROOT = PROJECT_ROOT / "<detected-service-subdir>"

TASK_WORKING_DIRS: dict[str, str] = {}

# ── Scaffold Bootstrap ────────────────────────────────────────
BOOTSTRAP_AFTER_TASK = "<scaffold-task-id>"
BOOTSTRAP_COMMAND = "<detected-bootstrap>"
BOOTSTRAP_WORKING_DIR = str(SERVICE_ROOT)

# ── Executors ──────────────────────────────────────────────────
# Each named executor is a coding agent CLI with type-specific config.
# Aider executors are named after their model (aider-local-qwen, etc.).
# Claude and Gemini executors can have variants for different model tiers.
EXECUTORS: dict[str, dict] = {
    "aider-local-qwen": {
        "type": "aider",
        "model": "<detected-model-string>",
        "api_base": "http://localhost:1234/v1",
        "api_key": "lm-studio",
    },
    # "claude": {
    #     "type": "claude",
    #     # Uses Pro plan auth — no API key needed
    # },
    # "gemini-flash": {
    #     "type": "gemini",
    #     "model": "gemini-2.5-flash",
    # },
}

# ── Executor Roles ─────────────────────────────────────────────
# Maps task role → ordered escalation chain of executor names.
# Position 0 is the default; subsequent entries are escalation tiers.
EXECUTOR_ROLES: dict[str, list[str]] = {
    "test":           ["<user-confirmed>"],
    "implementation": ["<user-confirmed>"],
    "scaffold":       ["<user-confirmed>"],
}

# ── Retry Limits ───────────────────────────────────────────────
MAX_RETRIES_PER_TASK = 3

# ── Tooling ────────────────────────────────────────────────────
DEFAULT_LINT_CMD = "<detected-lint-command>"
DEFAULT_LINT_FIX_CMD = "<detected-lint-fix-command>"  # None if no auto-fix
TEST_RUNNER = "<detected-test-runner>"
GLOBAL_TEST_CMD = "<detected-global-test-command>"

TASK_TEST_COMMANDS: dict[str, str | None] = {}
TASK_LINT_OVERRIDES: dict[str, str | None] = {}

# ── Aider-Specific ─────────────────────────────────────────────
AIDER_EXTRA_ARGS = [
    "--no-show-model-warnings",
    "--no-check-update",
    "--no-git",
    "--yes-always",
]


# ── Startup Validation ────────────────────────────────────────
def _validate_executors() -> None:
    """Validate all active executors at import time.

    Checks CLI availability and auth for every executor that appears
    in any EXECUTOR_ROLES chain. Fails fast with a clear error rather
    than waiting until a task needs that executor.
    """
    # Collect all executor names actually used in roles
    active_executors = set()
    for role, names in EXECUTOR_ROLES.items():
        active_executors.update(names)

    for name in active_executors:
        if name not in EXECUTORS:
            print(
                f"[config] ERROR: Executor '{name}' referenced in "
                f"EXECUTOR_ROLES but not defined in EXECUTORS.",
                file=sys.stderr,
            )
            sys.exit(1)

        cfg = EXECUTORS[name]
        executor_type = cfg.get("type")

        # Check CLI is on PATH
        cli_name = executor_type  # "aider", "claude", or "gemini"
        if not shutil.which(cli_name):
            print(
                f"[config] ERROR: Executor '{name}' requires '{cli_name}' "
                f"CLI but it is not on PATH.",
                file=sys.stderr,
            )
            sys.exit(1)

        # For aider executors with api_key_env, resolve the key
        if executor_type == "aider" and "api_key_env" in cfg:
            env_var = cfg["api_key_env"]
            value = os.environ.get(env_var)
            if not value:
                print(
                    f"[config] ERROR: Executor '{name}' requires "
                    f"environment variable {env_var} but it is not set.",
                    file=sys.stderr,
                )
                sys.exit(1)
            cfg["api_key"] = value


_validate_executors()
```

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
    current_executor_tier: int  # index into EXECUTOR_ROLES[role]
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

### `nodes/load_tasks.py` — Critical: Enum Serialization

When loading tasks from the Pydantic schema, use `mode="json"` in `model_dump()`
to serialize enum fields as their string values. Without this, `task_type` becomes
a `TaskType` enum object instead of the string `"test"` or `"implementation"`,
which causes `EXECUTOR_ROLES` lookups to fail silently (the key `"test"` doesn't
match the enum `TaskType.TEST`).

```python
def load_tasks_node(state: PipelineState) -> dict:
    ...
    ordered = decomposition.tasks_in_order()
    # CRITICAL: mode="json" ensures enums serialize as strings, not enum objects.
    # Without this, task_type becomes TaskType.TEST instead of "test",
    # which breaks EXECUTOR_ROLES lookups.
    all_tasks = [t.model_dump(mode="json") for t in ordered]
    ...
```

### `nodes/verify_task.py` — Auto-Fix Before Lint Check

```python
def verify_task_node(state: PipelineState) -> dict:
    ...
    # ── Auto-fix (before lint check) ──────────────────────────
    if not skip_lint and not is_scaffold and config.DEFAULT_LINT_FIX_CMD:
        py_files = _get_py_files(task, working_dir)
        if py_files:
            fix_cmd = f"{config.DEFAULT_LINT_FIX_CMD} {' '.join(py_files)}"
            agent_bridge.run_verification(fix_cmd, working_dir)
            # Best-effort — lint check below catches the remainder

    # ── Lint check ────────────────────────────────────────────
    ...
```

### `nodes/execute_task.py`

Resolves the executor from the task's role and current tier, then dispatches:

```python
def execute_task_node(state: PipelineState) -> dict:
    task_id = state["current_task_id"]
    task = _find_task(task_id, state["all_tasks"])
    tier = state.get("current_executor_tier", 0)

    executor_config, role = agent_bridge.resolve_executor(task, tier)

    print(
        f"[execute_task] {task_id} | role={role} "
        f"| executor={executor_config['type']} "
        f"| retry={state['current_retry']} | tier={tier}"
    )

    # ... compose command, invoke executor via agent_bridge ...
```

### `agent_bridge.py`

Executor dispatch and subprocess wrappers. See `references/executor-integration.md`
for the full implementation of each executor type.

### Other Files

- `graph.py` — See `references/langgraph-patterns.md`
- `nodes/bootstrap.py` — Unchanged from previous version
- `nodes/compose_prompt.py` — See `references/executor-integration.md` § "Prompt Composition"
- `nodes/report.py` — Unchanged
- `run.py` — Entry point with `--start` and `--max-retries` flags
- `requirements.txt` — `langgraph>=0.2.0`, `pydantic>=2.0.0`
- `README.md` — Feature-specific with executor configuration reference

## Generation Principles

- **Generate concrete code, not templates.** Fill in all config values from
  Phase 1. No placeholders in the runnable code.

- **Import the task schema, don't reinvent it.** Use `task_schema.py` from
  the tasks directory.

- **Serialize enums as strings.** Always use `model_dump(mode="json")` when
  converting Pydantic models to dicts. Enum objects don't match string keys
  in config lookups.

- **Keep nodes focused.** One responsibility per node.

- **Log everything.** Timestamped log file at
  `pipelines/<feature>/logs/run-<timestamp>.log` with full executor output.

- **Run without interruption.** Scaffold → bootstrap → execute is seamless.
  Intervention only needed when tasks exhaust all executor tiers.

- **Fail fast on configuration.** CLI availability, auth, and tooling commands
  validated at startup.
