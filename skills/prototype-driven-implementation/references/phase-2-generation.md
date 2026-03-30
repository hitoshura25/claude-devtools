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
DEFAULT_LINT_CMD = "<detected-lint-command>"
TEST_RUNNER = "<detected-test-runner>"  # e.g., "pytest", "uv run pytest"
GLOBAL_TEST_CMD = "<detected-global-test-command>"  # full suite

# Per-task test commands derived from tasks.json test_file paths.
# Format: {"task-id": "test command" or None}
# None means this task has no test gate (lint only).
TASK_TEST_COMMANDS: dict[str, str | None] = {
    # Generated from Phase 1 analysis
}

# Per-task lint command overrides.
# None means use DEFAULT_LINT_CMD.
TASK_LINT_OVERRIDES: dict[str, str | None] = {
    # Infrastructure tasks may override with hadolint, etc.
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
`PROJECT_ROOT` so the pipeline can run from any working directory.

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
2. **Files to create** — from `files`, with operation (create/modify) and descriptions
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

Logic:
1. Run lint command. If it fails, mark lint_passed = False.
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

Key function: `build_command(task, config)` → returns the full command list.

```python
def build_command(
    task: dict,
    model: str,
    api_base: str,
    api_key: str,
    message_file: str,
    lint_cmd: str | None,
    test_cmd: str | None,
    extra_args: list[str],
) -> list[str]:
    """Build the aider CLI command for a task."""
    cmd = [
        "aider",
        "--model", model,
        "--openai-api-base", api_base,
        "--openai-api-key", api_key,
        "--message-file", message_file,
    ]

    # Add files to edit
    for f in task.get("files", []):
        cmd.extend(["--file", f["path"]])

    # Lint
    if lint_cmd:
        cmd.extend(["--lint-cmd", lint_cmd, "--auto-lint"])

    # Test (implementation tasks only — test tasks skip --auto-test)
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
