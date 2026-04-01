# LangGraph Patterns — Pipeline State Machine Design

## Graph Structure

The pipeline is a task execution loop with verification, auto-fix, circuit
breakers, model escalation, and a tooling bootstrap step after scaffold tasks.

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

Scaffold tasks present a chicken-and-egg problem: they create the service
directory and project config files, but Aider needs a `cwd` to run from,
and lint/test tools aren't available until the tooling environment is
bootstrapped.

The pipeline handles this in two steps:

### Step 1: Scaffold tasks run from the project root

Scaffold tasks (tasks with `phase: "scaffold"`) that create the service
directory itself must run from the **project root**, not the service root.
The service root doesn't exist yet — Aider creates it as part of the task.

For scaffold tasks:
- `cwd` = project root
- `--file` paths are project-root-relative (no rebasing needed)
- `--lint-cmd` is typically skipped (no tools installed yet)

### Step 2: Bootstrap after scaffold

After the scaffold task that creates the project config file (e.g.,
`pyproject.toml`, `package.json`), the pipeline runs a **bootstrap command**
to initialize the tooling environment. This is configured in `config.py`:

```python
BOOTSTRAP_AFTER_TASK = "task-01"
BOOTSTRAP_COMMAND = "uv sync"
BOOTSTRAP_WORKING_DIR = str(SERVICE_ROOT)
```

The bootstrap is a node in the graph that runs between `verify_task` (for
the scaffold task) and `pick_next_task` (for the next task). It's only
triggered once, for the specific task configured in `BOOTSTRAP_AFTER_TASK`.

After bootstrap completes, all subsequent tasks use the service root as
their working directory, and lint/test tools are available.

## StateGraph Definition Pattern

```python
from langgraph.graph import StateGraph, START, END
from pipeline_state import PipelineState

def build_graph() -> StateGraph:
    graph = StateGraph(PipelineState)

    # Add nodes
    graph.add_node("load_tasks", load_tasks_node)
    graph.add_node("pick_next_task", pick_next_task_node)
    graph.add_node("compose_prompt", compose_prompt_node)
    graph.add_node("execute_task", execute_task_node)
    graph.add_node("verify_task", verify_task_node)
    graph.add_node("bootstrap", bootstrap_node)
    graph.add_node("retry_task", retry_task_node)
    graph.add_node("escalate_model", escalate_model_node)
    graph.add_node("mark_failed", mark_failed_node)
    graph.add_node("report", report_node)

    # Entry
    graph.add_edge(START, "load_tasks")
    graph.add_edge("load_tasks", "pick_next_task")

    # Pick next → either compose (has a task) or report (done)
    graph.add_conditional_edges(
        "pick_next_task",
        route_after_pick,
        {"has_task": "compose_prompt", "all_done": "report"},
    )

    # Compose → execute → verify
    graph.add_edge("compose_prompt", "execute_task")
    graph.add_edge("execute_task", "verify_task")

    # Verify → pass / bootstrap / retry / escalate / fail
    graph.add_conditional_edges(
        "verify_task",
        route_after_verify,
        {
            "passed": "pick_next_task",
            "passed_needs_bootstrap": "bootstrap",
            "retry": "retry_task",
            "escalate": "escalate_model",
            "exhausted": "mark_failed",
        },
    )

    # Bootstrap → pick next
    graph.add_edge("bootstrap", "pick_next_task")

    # Retry loops back to compose (rebuild prompt with error context)
    graph.add_edge("retry_task", "compose_prompt")

    # Escalate bumps tier, resets retries, re-enters compose
    graph.add_edge("escalate_model", "compose_prompt")

    # Mark failed → pick next (continue with remaining tasks)
    graph.add_edge("mark_failed", "pick_next_task")

    # Report is terminal
    graph.add_edge("report", END)

    return graph
```

## Routing Functions

### `route_after_pick`

Decides whether there's another task to execute or all tasks are done.

```python
def route_after_pick(state: PipelineState) -> str:
    if state["current_task_id"] is not None:
        return "has_task"
    return "all_done"
```

### `route_after_verify`

Decides what to do after verification: advance (with optional bootstrap),
retry at the same tier, escalate to a stronger model, or give up.

```python
def route_after_verify(state: PipelineState) -> str:
    task_id = state["current_task_id"]
    result = state["task_results"][task_id]

    if result["status"] in ("passed", "degraded"):
        # Check if this task triggers a bootstrap
        if (
            task_id == config.BOOTSTRAP_AFTER_TASK
            and not state.get("bootstrap_done")
        ):
            return "passed_needs_bootstrap"
        return "passed"

    # Task failed — determine next action

    # Can we retry at the current tier?
    if state["current_retry"] < config.MAX_RETRIES_PER_TASK:
        return "retry"

    # Retries exhausted at current tier — can we escalate?
    task = _find_task(task_id, state["all_tasks"])
    task_type = task.get("task_type", "implementation")
    role = "scaffold" if task.get("phase") == "scaffold" else task_type
    models_for_role = config.MODEL_ROLES.get(role, config.MODEL_ROLES["implementation"])
    current_tier = state.get("current_model_tier", 0)

    if current_tier + 1 < len(models_for_role):
        return "escalate"

    # No more tiers — mark as failed
    return "exhausted"
```

## Node Implementation Patterns

### bootstrap

Runs the tooling environment initialization command after the scaffold task.

```python
def bootstrap_node(state: PipelineState) -> dict:
    cmd = config.BOOTSTRAP_COMMAND
    working_dir = config.BOOTSTRAP_WORKING_DIR
    print(f"[bootstrap] Running: {cmd} (in {working_dir})")

    rc, stdout, stderr = aider_bridge.run_verification(cmd, working_dir)
    if rc != 0:
        print(f"[bootstrap] WARNING: bootstrap failed (exit {rc})")
        print(f"  stdout: {stdout[:500]}")
        print(f"  stderr: {stderr[:500]}")
    else:
        print("[bootstrap] Tooling environment initialized successfully")

    return {"bootstrap_done": True}
```

### pick_next_task

Finds the next unprocessed task in topological order. A task is eligible if:
1. It hasn't been processed yet (not in `task_results`)
2. All its dependencies have passed or been degraded

If a task's dependency failed, skip that task too. Mark it as "skipped".

```python
def pick_next_task_node(state: PipelineState) -> dict:
    results = state["task_results"]
    task_map = {t["id"]: t for t in state["all_tasks"]}

    for task_id in state["task_order"]:
        if task_id in results:
            continue

        task = task_map[task_id]
        deps = task.get("depends_on", [])

        blocked_by = []
        for dep in deps:
            dep_status = results.get(dep, {}).get("status")
            if dep_status not in ("passed", "degraded"):
                blocked_by.append(dep)

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
            "current_model_tier": 0,
            "current_lint_errors": "",
            "current_test_errors": "",
        }

    return {"current_task_id": None, "is_complete": True}
```

Note: `current_model_tier` is reset to 0 when picking a new task. Each task
starts with the default model for its role.

### retry_task

Increments the retry counter. The prompt composer includes error context from
the previous attempt on retry.

```python
def retry_task_node(state: PipelineState) -> dict:
    new_retry = state["current_retry"] + 1
    print(
        f"[retry_task] Retrying {state['current_task_id']} "
        f"(attempt {new_retry + 1}/{config.MAX_RETRIES_PER_TASK + 1})"
    )
    return {"current_retry": new_retry}
```

### escalate_model

Bumps the model tier and resets retries. The task re-enters the
compose→execute→verify loop with a stronger model.

```python
def escalate_model_node(state: PipelineState) -> dict:
    """Escalate to the next model tier and reset retries.

    Called when the current model has exhausted its retry budget.
    The stronger model gets a fresh set of retries. The prompt composer
    will include error context from the previous tier's attempts.
    """
    task_id = state["current_task_id"]
    new_tier = state.get("current_model_tier", 0) + 1

    # Resolve the new model name for logging
    task = _find_task(task_id, state["all_tasks"])
    task_type = task.get("task_type", "implementation")
    role = "scaffold" if task.get("phase") == "scaffold" else task_type
    models_for_role = config.MODEL_ROLES.get(role, config.MODEL_ROLES["implementation"])
    new_model_name = models_for_role[new_tier]

    print(
        f"[escalate] {task_id}: tier {new_tier} → "
        f"model '{new_model_name}' (retries reset to 0)"
    )

    return {
        "current_model_tier": new_tier,
        "current_retry": 0,
    }
```

### mark_failed

Records the task as permanently failed and allows the pipeline to continue.

```python
def mark_failed_node(state: PipelineState) -> dict:
    task_id = state["current_task_id"]
    existing = state["task_results"].get(task_id, {})
    tier = state.get("current_model_tier", 0)
    print(
        f"[mark_failed] {task_id} exhausted all retries at tier {tier} "
        f"— marking failed"
    )
    return {
        "task_results": {
            **state["task_results"],
            task_id: {**existing, "status": "failed"},
        },
        "current_task_id": None,
    }
```

## State Update Pattern

LangGraph nodes return partial state updates as dicts. The framework merges
them into the full state. For nested dicts like `task_results`, return the
full dict with the updated entry — LangGraph does shallow merge, not deep merge.

```python
# Correct: return full task_results with updated entry
return {
    "task_results": {
        **state["task_results"],
        task_id: new_result,
    }
}

# Wrong: returns only the new entry, losing all previous results
return {"task_results": {task_id: new_result}}
```

## Error Handling

Wrap all subprocess calls (Aider, lint, test, bootstrap) in try/except. A
crashed subprocess should not crash the pipeline — it should be treated as a
task failure and enter the retry/escalation flow.

```python
try:
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
except subprocess.TimeoutExpired:
    return {"error_summary": "Aider timed out after 600s"}
except FileNotFoundError:
    return {"error_summary": "aider command not found — is it installed?"}
```

The 600s timeout is a safety net for cases where Aider hangs. It's separate
from LM Studio's token generation cap, which should also be set (see handoff
docs).
