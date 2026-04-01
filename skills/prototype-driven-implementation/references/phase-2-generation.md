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
import os
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

# ── Models ─────────────────────────────────────────────────────
# Define each model once. The name is the key used in MODEL_ROLES.
MODELS = {
    "local-qwen": {
        "model": "<detected-model-string>",
        "api_base": "http://localhost:1234/v1",
        "api_key": "lm-studio",
    },
    # Cloud models use api_key_env to resolve from environment at startup.
    # "sonnet": {
    #     "model": "anthropic/claude-sonnet-4",
    #     "api_base": "https://api.anthropic.com/v1",
    #     "api_key_env": "ANTHROPIC_API_KEY",
    # },
}

# ── Model Roles ────────────────────────────────────────────────
# Maps task role → ordered list of model names to try.
# Position 0 is the default; subsequent entries are escalation tiers.
# A model can appear in multiple roles without duplicating its config.
MODEL_ROLES = {
    "test":           ["<user-confirmed>"],
    "implementation": ["<user-confirmed>"],
    "scaffold":       ["<user-confirmed>"],
}

# ── Retry Limits ───────────────────────────────────────────────
MAX_RETRIES_PER_TASK = 3

# ── Tooling ────────────────────────────────────────────────────
DEFAULT_LINT_CMD = "<detected-lint-command>"
DEFAULT_LINT_FIX_CMD = "<detected-lint-fix-command>"  # None if linter has no auto-fix
TEST_RUNNER = "<detected-test-runner>"
GLOBAL_TEST_CMD = "<detected-global-test-command>"

TASK_TEST_COMMANDS: dict[str, str | None] = {}
TASK_LINT_OVERRIDES: dict[str, str | None] = {}

# ── Aider ──────────────────────────────────────────────────────
AIDER_EXTRA_ARGS = [
    "--no-show-model-warnings",
    "--no-check-update",
    "--no-git",
    "--yes-always",
]


# ── Startup Validation ────────────────────────────────────────
def _resolve_api_keys():
    """Resolve api_key_env references to actual values at import time.

    Fails fast with a clear error if a required environment variable
    is not set, rather than waiting until the first task that needs
    that model.
    """
    for name, cfg in MODELS.items():
        if "api_key_env" in cfg:
            env_var = cfg["api_key_env"]
            value = os.environ.get(env_var)
            if not value:
                # Check if this model is actually used in any role
                used_in_roles = [
                    role for role, models in MODEL_ROLES.items()
                    if name in models
                ]
                if used_in_roles:
                    print(
                        f"[config] ERROR: Model '{name}' requires "
                        f"environment variable {env_var} but it is not set.\n"
                        f"  This model is used in roles: {used_in_roles}\n"
                        f"  Set it with: export {env_var}=<your-key>",
                        file=sys.stderr,
                    )
                    sys.exit(1)
            else:
                cfg["api_key"] = value

_resolve_api_keys()
```

Fill in all placeholder values from Phase 1. Use absolute paths for
`PROJECT_ROOT` and `SERVICE_ROOT`. The `MODELS` and `MODEL_ROLES` sections
are populated from the user's confirmed role assignments in Phase 1.

### Model Resolution at Runtime

The `execute_task` node resolves which model to use based on task type and
the current escalation tier:

```python
def resolve_model(task: dict, current_tier: int) -> tuple[dict, str]:
    """Return (model_config, role) for the given task and tier.

    Determines the role from the task's type and phase, then looks up
    the model at the current tier position in that role's escalation
    chain.
    """
    task_type = task.get("task_type", "implementation")
    if task.get("phase") == "scaffold":
        role = "scaffold"
    else:
        role = task_type  # "test" or "implementation"

    models_for_role = config.MODEL_ROLES.get(role, config.MODEL_ROLES["implementation"])
    tier_idx = min(current_tier, len(models_for_role) - 1)
    model_name = models_for_role[tier_idx]
    model_config = config.MODELS[model_name]

    return model_config, role
```

### Scaffold Tasks and Working Directory

Scaffold tasks create the service directory itself — they can't run from a
directory that doesn't exist yet. The `aider_bridge.get_task_working_dir()`
function handles this automatically:

```python
def get_task_working_dir(task_id: str) -> str:
    if task_id in config.TASK_WORKING_DIRS:
        return config.TASK_WORKING_DIRS[task_id]

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
    current_model_tier: int  # index into MODEL_ROLES[role] for current task
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

### `verify_task.py` — Auto-Fix Before Lint Check

The `verify_task` node runs independently after Aider exits. It now includes
an auto-fix step before the lint check to resolve trivially fixable errors
(import sorting, unused imports, etc.) that small models consistently fail to
fix during Aider's reflection loop.

```python
def verify_task_node(state: PipelineState) -> dict:
    task_id = state["current_task_id"]
    task = _find_task(task_id, state["all_tasks"])
    working_dir = aider_bridge.get_task_working_dir(task_id, state["all_tasks"])
    task_type = task.get("task_type", "implementation")

    # ── Auto-fix (before lint check) ──────────────────────────
    # Run the linter's auto-fix on edited files to resolve trivially
    # fixable errors. This prevents models from wasting reflection
    # cycles on import sorting (I001), unused imports (F401), etc.
    if config.DEFAULT_LINT_FIX_CMD:
        is_scaffold = task.get("phase") == "scaffold"
        py_files = _get_python_files(task, is_scaffold, working_dir)
        if py_files:
            files_arg = " ".join(py_files)
            fix_cmd = f"{config.DEFAULT_LINT_FIX_CMD} {files_arg}"
            aider_bridge.run_verification(fix_cmd, working_dir)
            # Auto-fix is best-effort — ignore the return code.
            # The lint check below will catch anything unfixable.

    # ── Lint check ────────────────────────────────────────────
    # (existing lint check logic, unchanged)
    ...

    # ── Test check ────────────────────────────────────────────
    # (existing test check logic, unchanged)
    ...
```

The auto-fix step:
- Runs before the lint check, not after
- Is best-effort — if auto-fix fails or partially fixes, the lint check
  catches the remainder
- Only runs on Python files (or equivalent for the language) from the
  current task's file list
- Does not run for scaffold tasks where lint is skipped

### `graph.py`

See `references/langgraph-patterns.md` for the full graph structure including
the bootstrap node and model escalation.

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

Invokes Aider via `aider_bridge`. Resolves the model from the task's role and
the current escalation tier. Does NOT verify — that's `verify_task`.

```python
def execute_task_node(state: PipelineState) -> dict:
    task_id = state["current_task_id"]
    task = _find_task(task_id, state["all_tasks"])

    # Resolve model from role + escalation tier
    model_config, role = resolve_model(task, state.get("current_model_tier", 0))

    print(
        f"[execute_task] {task_id} (retry={state['current_retry']}) "
        f"model={model_config['model']} role={role}"
    )

    # ... build command, invoke Aider, return results ...
```

### `nodes/bootstrap.py`

Runs the tooling environment initialization command after the scaffold task.
See `references/langgraph-patterns.md` § "Scaffold Tasks and Working Directory".

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
    python run.py --model <string>   # Override the default model for all roles
    python run.py --max-retries 5    # Override retry limit
"""
```

Supports:
- `--start <task-id>` — skip tasks before this ID (for resuming after fixes)
- `--model <model-string>` — override the default model for all roles
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
  enable escalation as a localized graph change.

- **Log everything.** Timestamped log file at
  `pipelines/<feature>/logs/run-<timestamp>.log` with full Aider output,
  verification results, and state transitions.

- **Run without interruption.** Scaffold → bootstrap → execute is seamless.
  The user starts the pipeline and walks away. Intervention is only needed
  when tasks exhaust retries at all available model tiers.

- **Fail fast on configuration.** API keys, model availability, and tooling
  commands are validated at startup, not when the first task that needs them
  runs.
