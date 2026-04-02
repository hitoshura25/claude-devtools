# LangGraph Patterns — Pipeline State Machine Design

## Graph Structure

The pipeline is a task execution loop with verification, auto-fix, circuit
breakers, executor escalation, and a tooling bootstrap step after scaffold tasks.

```
                          ┌──────────────────────────────────────────────────────┐
                          │                                                      │
START ──→ load_tasks ──→ pick_next_task ──→ compose_prompt ──→ execute_task ──→ verify_task
                               ↑                                                     │
                               │                     ┌────────────────────────────────┤
                               │                     │                                │
                               │                task passed                    task failed
                               │                     │                                │
                               │               needs bootstrap?            retries < max?
                               │                ┌────┴────┐                ┌─────┴─────┐
                               │              yes         no             yes            no
                               │               │          │               │             │
                               │           bootstrap      │          retry_task    more tiers?
                               │               │          │               │        ┌───┴───┐
                               │               ▼          ▼               │      yes       no
                               │          (back to pick)◄─┘               │       │        │
                               │               ▲                          │   escalate  mark_failed
                               │               │                          │       │        │
                               ├───────────────┼──────────────────────────┘       │        │
                               │               │                                  │        │
                               │               └──────────────────────────────────┘        │
                               │                                                           │
                               └───────────────────────────────────────────────────────────┘
                          (no more tasks)
                               │
                               ▼
                            report ──→ END
```

## Scaffold Tasks and Working Directory

Scaffold tasks create the service directory and project config files. They
can't run from a directory that doesn't exist yet, and lint/test tools aren't
available until the tooling environment is bootstrapped.

### Step 1: Scaffold tasks run from the project root

For scaffold tasks:
- `cwd` = project root
- File paths are project-root-relative (no rebasing needed, even for Aider)
- Lint is typically skipped (tools not installed yet)

### Step 2: Bootstrap after scaffold

After the scaffold task that creates the project config file, the pipeline
runs a bootstrap command (`uv sync`, `npm install`, etc.) to initialize the
tooling environment. Configured in `config.py`:

```python
BOOTSTRAP_AFTER_TASK = "task-01"
BOOTSTRAP_COMMAND = "uv sync"
BOOTSTRAP_WORKING_DIR = str(SERVICE_ROOT)
```

## StateGraph Definition

```python
from langgraph.graph import StateGraph, START, END
from pipeline_state import PipelineState

def build_graph() -> StateGraph:
    graph = StateGraph(PipelineState)

    graph.add_node("load_tasks", load_tasks_node)
    graph.add_node("pick_next_task", pick_next_task_node)
    graph.add_node("compose_prompt", compose_prompt_node)
    graph.add_node("execute_task", execute_task_node)
    graph.add_node("verify_task", verify_task_node)
    graph.add_node("bootstrap", bootstrap_node)
    graph.add_node("retry_task", retry_task_node)
    graph.add_node("escalate_executor", escalate_executor_node)
    graph.add_node("mark_failed", mark_failed_node)
    graph.add_node("report", report_node)

    graph.add_edge(START, "load_tasks")
    graph.add_edge("load_tasks", "pick_next_task")

    graph.add_conditional_edges(
        "pick_next_task",
        route_after_pick,
        {"has_task": "compose_prompt", "all_done": "report"},
    )

    graph.add_edge("compose_prompt", "execute_task")
    graph.add_edge("execute_task", "verify_task")

    graph.add_conditional_edges(
        "verify_task",
        route_after_verify,
        {
            "passed": "pick_next_task",
            "passed_needs_bootstrap": "bootstrap",
            "retry": "retry_task",
            "escalate": "escalate_executor",
            "exhausted": "mark_failed",
        },
    )

    graph.add_edge("bootstrap", "pick_next_task")
    graph.add_edge("retry_task", "compose_prompt")
    graph.add_edge("escalate_executor", "compose_prompt")
    graph.add_edge("mark_failed", "pick_next_task")
    graph.add_edge("report", END)

    return graph
```

## Routing Functions

### `route_after_pick`

```python
def route_after_pick(state: PipelineState) -> str:
    if state.get("current_task_id") is not None:
        return "has_task"
    return "all_done"
```

### `route_after_verify`

Decides: advance (with optional bootstrap), retry at same tier, escalate
to the next executor, or give up.

```python
def route_after_verify(state: PipelineState) -> str:
    task_id = state["current_task_id"]
    result = state["task_results"].get(task_id, {})
    status = result.get("status", "failed")

    if status in ("passed", "degraded"):
        if (
            task_id == config.BOOTSTRAP_AFTER_TASK
            and not state.get("bootstrap_done")
        ):
            return "passed_needs_bootstrap"
        return "passed"

    # Task failed — can we retry at the current tier?
    if state.get("current_retry", 0) < config.MAX_RETRIES_PER_TASK:
        return "retry"

    # Retries exhausted — can we escalate to a stronger executor?
    task = _find_task(task_id, state["all_tasks"])
    task_type = task.get("task_type", "implementation")
    phase = task.get("phase", "")
    role = "scaffold" if phase in ("scaffold", "infrastructure") else task_type

    executors_for_role = config.EXECUTOR_ROLES.get(
        role, config.EXECUTOR_ROLES["implementation"]
    )
    current_tier = state.get("current_executor_tier", 0)

    if current_tier + 1 < len(executors_for_role):
        return "escalate"

    return "exhausted"
```

## Node Implementation Patterns

### pick_next_task

Finds the next eligible task. Resets `current_executor_tier` to 0 for each
new task.

```python
def pick_next_task_node(state: PipelineState) -> dict:
    results = state["task_results"]
    task_map = {t["id"]: t for t in state["all_tasks"]}

    for task_id in state["task_order"]:
        if task_id in results:
            continue

        task = task_map[task_id]
        deps = task.get("depends_on", [])
        blocked_by = [
            dep for dep in deps
            if results.get(dep, {}).get("status") not in ("passed", "degraded")
        ]

        if blocked_by:
            return {
                "task_results": {
                    **results,
                    task_id: {
                        "task_id": task_id,
                        "status": "skipped",
                        "retries": 0,
                        "lint_passed": False,
                        "test_passed": None,
                        "error_summary": f"Skipped — dependency failed: {blocked_by}",
                    },
                },
            }

        return {
            "current_task_id": task_id,
            "current_retry": 0,
            "current_executor_tier": 0,
            "current_lint_errors": "",
            "current_test_errors": "",
        }

    return {"current_task_id": None, "is_complete": True}
```

### retry_task

Increments retry counter. The prompt composer includes error context on retry.

```python
def retry_task_node(state: PipelineState) -> dict:
    new_retry = state.get("current_retry", 0) + 1
    return {"current_retry": new_retry}
```

### escalate_executor

Bumps executor tier, resets retries. The task re-enters the
compose→execute→verify loop with a stronger executor.

```python
def escalate_executor_node(state: PipelineState) -> dict:
    task_id = state["current_task_id"]
    new_tier = state.get("current_executor_tier", 0) + 1

    task = _find_task(task_id, state["all_tasks"])
    task_type = task.get("task_type", "implementation")
    phase = task.get("phase", "")
    role = "scaffold" if phase in ("scaffold", "infrastructure") else task_type
    executors_for_role = config.EXECUTOR_ROLES.get(
        role, config.EXECUTOR_ROLES["implementation"]
    )
    new_executor_name = executors_for_role[min(new_tier, len(executors_for_role) - 1)]

    print(
        f"[escalate] {task_id}: tier {new_tier} → "
        f"executor '{new_executor_name}' (retries reset)"
    )
    return {"current_executor_tier": new_tier, "current_retry": 0}
```

### mark_failed

Records the task as permanently failed.

```python
def mark_failed_node(state: PipelineState) -> dict:
    task_id = state["current_task_id"]
    existing = state["task_results"].get(task_id, {})
    return {
        "task_results": {
            **state["task_results"],
            task_id: {**existing, "status": "failed"},
        },
        "current_task_id": None,
    }
```

### bootstrap

Runs the tooling environment initialization command:

```python
def bootstrap_node(state: PipelineState) -> dict:
    cmd = config.BOOTSTRAP_COMMAND
    working_dir = config.BOOTSTRAP_WORKING_DIR
    rc, stdout, stderr = agent_bridge.run_verification(cmd, working_dir)
    if rc != 0:
        print(f"[bootstrap] WARNING: failed (exit {rc})")
    else:
        print("[bootstrap] Tooling environment initialized")
    return {"bootstrap_done": True}
```

## State Update Pattern

LangGraph does shallow merge. For nested dicts like `task_results`, return
the full dict with the updated entry:

```python
# Correct
return {"task_results": {**state["task_results"], task_id: new_result}}

# Wrong — loses all previous results
return {"task_results": {task_id: new_result}}
```

## Error Handling

Wrap all subprocess calls in try/except. A crashed subprocess is a task
failure, not a pipeline crash:

```python
try:
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
except subprocess.TimeoutExpired:
    return {"error_summary": "Executor timed out after 600s"}
except FileNotFoundError:
    return {"error_summary": f"{executor_type} CLI not found — is it installed?"}
```
