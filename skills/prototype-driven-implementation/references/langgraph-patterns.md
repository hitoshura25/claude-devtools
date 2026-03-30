# LangGraph Patterns — Pipeline State Machine Design

## Graph Structure

The pipeline is a task execution loop with verification and circuit breakers.

```
                          ┌──────────────────────────────────────────┐
                          │                                          │
START ──→ load_tasks ──→ pick_next_task ──→ compose_prompt ──→ execute_task ──→ verify_task
                               ↑                                                     │
                               │                          ┌──────────────────────────┤
                               │                          │                          │
                               │                     task passed              task failed
                               │                          │                          │
                               │                          │               retries < max?
                               │                          │                ┌────┴────┐
                               │                          │              yes         no
                               │                          │               │          │
                               │                          │          retry_task   mark_failed
                               │                          │               │          │
                               │                          ▼               │          │
                               ├──────────────────── (back to pick) ◄────┘          │
                               │                                                    │
                               ├────────────────────────────────────────────────────┘
                               │
                          (no more tasks)
                               │
                               ▼
                            report ──→ END
```

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

    # Verify → pass (pick next) or fail (retry or mark failed)
    graph.add_conditional_edges(
        "verify_task",
        route_after_verify,
        {"passed": "pick_next_task", "retry": "retry_task", "exhausted": "mark_failed"},
    )

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

Decides what to do after verification: advance, retry, or give up.

```python
def route_after_verify(state: PipelineState) -> str:
    task_id = state["current_task_id"]
    result = state["task_results"][task_id]

    if result["status"] == "passed":
        return "passed"

    if state["current_retry"] < MAX_RETRIES_PER_TASK:
        return "retry"

    return "exhausted"
```

## Node Implementation Patterns

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
                "current_task_id": None,  # Will be set after marking skip
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

## Dry Run Mode

The graph supports a `--dry-run` flag by having `execute_task` check a config
flag and skip Aider invocation:

```python
def execute_task_node(state: PipelineState) -> dict:
    task_id = state["current_task_id"]
    task = next(t for t in state["all_tasks"] if t["id"] == task_id)

    if DRY_RUN:
        print(f"  [DRY RUN] Would execute: {task['title']}")
        print(f"            Files: {[f['path'] for f in task['files']]}")
        # Mark as passed so the graph continues
        return {
            "task_results": {
                **state["task_results"],
                task_id: {
                    "task_id": task_id,
                    "status": "passed",
                    "retries": 0,
                    "lint_passed": True,
                    "test_passed": True,
                    "error_summary": "",
                },
            },
        }

    # ... actual Aider invocation
```

In dry-run mode, `verify_task` is also skipped (the task is already marked
passed by `execute_task`). The routing function sees "passed" and moves on.

## Error Handling

Wrap all subprocess calls (Aider, lint, test) in try/except. A crashed
subprocess should not crash the pipeline — it should be treated as a task
failure and enter the retry/escalation flow.

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
