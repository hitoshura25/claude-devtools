# LangGraph Patterns — Pipeline State Machine Design

## Graph Structure

The pipeline is a task execution loop with verification, circuit breakers,
and a tooling bootstrap step after scaffold tasks.

```
                          ┌──────────────────────────────────────────────────────┐
                          │                                                      │
START ──→ load_tasks ──→ pick_next_task ──→ compose_prompt ──→ execute_task ──→ verify_task
                               ↑                                                     │
                               │                          ┌──────────────────────────┤
                               │                          │                          │
                               │                     task passed              task failed
                               │                          │                          │
                               │                     needs bootstrap?     retries < max?
                               │                      ┌───┴───┐           ┌────┴────┐
                               │                    yes        no        yes         no
                               │                     │         │          │          │
                               │                  bootstrap    │     retry_task  mark_failed
                               │                     │         │          │          │
                               │                     ▼         ▼          │          │
                               ├──────────────── (back to pick) ◄────────┘          │
                               │                                                    │
                               ├────────────────────────────────────────────────────┘
                               │
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
# Bootstrap: run after the scaffold task that creates the project config.
# This initializes the service's tooling environment so lint/test commands
# work for all subsequent tasks.
BOOTSTRAP_AFTER_TASK = "task-01"  # The scaffold task ID
BOOTSTRAP_COMMAND = "uv sync"     # or "npm install", "./gradlew build", etc.
BOOTSTRAP_WORKING_DIR = str(SERVICE_ROOT)  # Run from the newly-created service dir
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

    # Verify → pass (maybe bootstrap, then pick next) or fail (retry/mark)
    graph.add_conditional_edges(
        "verify_task",
        route_after_verify,
        {
            "passed": "pick_next_task",
            "passed_needs_bootstrap": "bootstrap",
            "retry": "retry_task",
            "exhausted": "mark_failed",
        },
    )

    # Bootstrap → pick next
    graph.add_edge("bootstrap", "pick_next_task")

    # Retry loops back to compose (rebuild prompt with error context)
    graph.add_edge("retry_task", "compose_prompt")

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
retry, or give up.

```python
def route_after_verify(state: PipelineState) -> str:
    task_id = state["current_task_id"]
    result = state["task_results"][task_id]

    if result["status"] == "passed":
        # Check if this task triggers a bootstrap
        if task_id == config.BOOTSTRAP_AFTER_TASK and not state.get("bootstrap_done"):
            return "passed_needs_bootstrap"
        return "passed"

    if state["current_retry"] < config.MAX_RETRIES_PER_TASK:
        return "retry"

    return "exhausted"
```

## Node Implementation Patterns

### bootstrap

Runs the tooling environment initialization command after the scaffold task.

```python
def bootstrap_node(state: PipelineState) -> dict:
    """Initialize the service's tooling environment.

    Runs after the scaffold task creates the project config file.
    This makes lint/test tools available for all subsequent tasks.
    """
    cmd = config.BOOTSTRAP_COMMAND
    working_dir = config.BOOTSTRAP_WORKING_DIR
    print(f"[bootstrap] Running: {cmd} (in {working_dir})")

    rc, stdout, stderr = run_command(cmd, working_dir)
    if rc != 0:
        print(f"[bootstrap] WARNING: bootstrap failed (exit {rc})")
        print(f"  stdout: {stdout[:500]}")
        print(f"  stderr: {stderr[:500]}")
        # Don't crash the pipeline — lint/test failures downstream
        # will surface the problem clearly
    else:
        print("[bootstrap] Tooling environment initialized successfully")

    return {"bootstrap_done": True}
```

### pick_next_task

Finds the next unprocessed task in topological order. A task is eligible if:
1. It hasn't been processed yet (not in `task_results`)
2. All its dependencies have passed or been skipped

If a task's dependency failed, skip that task too (can't build on a failed
foundation). Mark it as "skipped" in results.

```python
def pick_next_task_node(state: PipelineState) -> dict:
    for task_id in state["task_order"]:
        if task_id in state["task_results"]:
            continue  # Already processed

        # Check dependencies
        task = next(t for t in state["all_tasks"] if t["id"] == task_id)
        deps_ok = all(
            state["task_results"].get(dep, {}).get("status") in ("passed", "degraded")
            for dep in task.get("depends_on", [])
        )

        if not deps_ok:
            # Skip — dependency failed
            return {
                "task_results": {
                    **state["task_results"],
                    task_id: {
                        "task_id": task_id,
                        "status": "skipped",
                        "retries": 0,
                        "lint_passed": False,
                        "test_passed": None,
                        "error_summary": "Skipped — dependency failed",
                    },
                },
            }

        return {
            "current_task_id": task_id,
            "current_retry": 0,
        }

    # No more tasks
    return {"current_task_id": None, "is_complete": True}
```

Note: The skip logic above is simplified. In practice, `pick_next_task` should
loop past skipped tasks until it finds an eligible one or runs out. Handle
this by having the routing function check `is_complete` separately from
`current_task_id`.

### Working directory per task

The `execute_task` and `verify_task` nodes use `aider_bridge.get_task_working_dir()`
to determine the correct cwd for each task. The logic:

```python
def get_task_working_dir(task_id: str) -> str:
    """Determine the working directory for a task.

    Scaffold tasks run from the project root (the service dir may not exist yet).
    All other tasks run from the service root (where lint/test tools are installed).
    Per-task overrides in config take priority.
    """
    # Explicit override
    if task_id in config.TASK_WORKING_DIRS:
        return config.TASK_WORKING_DIRS[task_id]

    # Scaffold tasks: service dir may not exist yet, use project root
    task = _find_task_by_id(task_id)
    if task and task.get("phase") == "scaffold":
        return str(config.PROJECT_ROOT)

    # All other tasks: use service root
    return str(config.SERVICE_ROOT)
```

Scaffold tasks don't need path rebasing (their file paths are project-root-
relative, and Aider's cwd is the project root). All other tasks get their
paths rebased to be relative to the service root.

### retry_task

Increments the retry counter. The prompt composer can use the retry count to
include error context from the previous attempt.

```python
def retry_task_node(state: PipelineState) -> dict:
    return {"current_retry": state["current_retry"] + 1}
```

### mark_failed

Records the task as failed and allows the pipeline to continue with remaining
tasks.

```python
def mark_failed_node(state: PipelineState) -> dict:
    task_id = state["current_task_id"]
    result = state["task_results"].get(task_id, {})
    return {
        "task_results": {
            **state["task_results"],
            task_id: {**result, "status": "failed"},
        },
    }
```

## v2 Extension Point: Escalation

When adding multi-model escalation in v2, the change is:

1. Add a `current_tier` field to `PipelineState`
2. Change `route_after_verify` to check `current_tier` before deciding "retry"
   vs "exhausted":
   - If retries exhausted AND more tiers available → "escalate"
   - If retries exhausted AND no more tiers → "exhausted"
3. Add an `"escalate"` node that bumps `current_tier` and resets `current_retry`
4. Add the conditional edge from `verify_task` to `escalate`
5. `escalate` edges back to `compose_prompt` (which adjusts the prompt for
   the new model tier)

The graph structure is designed to make this a localized change — no existing
nodes need to be modified, just the routing function and one new node.

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
