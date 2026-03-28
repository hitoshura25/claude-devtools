---
name: prototype-driven-task-decomposition
description: >
  Break a prototype-driven design doc into structured implementation tasks with
  a validated PydanticAI schema. Use this skill when the user has a design doc
  from prototype-driven-planning and wants to decompose it into tasks for
  implementation — whether they say "decompose", "break down", "create tasks",
  "task decomposition", or invoke /prototype-task-decompose. Also trigger when
  the user mentions wanting to prepare tasks for local models, Aider, or a
  multi-model pipeline based on a design doc. Do NOT trigger on general planning
  requests or when the user wants to create a design doc (that's
  prototype-driven-planning).
---

# Prototype-Driven Task Decomposition

Turn a vetted design doc into structured, schema-validated implementation tasks
that local models can execute independently.

This skill reads a design doc produced by `prototype-driven-planning`, decomposes
it into tasks sized for a single model session, and outputs both human-readable
markdown and machine-readable JSON validated against a PydanticAI schema.

## Quick Reference

| Input | Output |
|-------|--------|
| Design doc at `docs/design/<feature>.md` | `tasks/<feature>/tasks.json` (machine-readable) |
| Prototype at `prototypes/<feature>/` | `tasks/<feature>/task-NN-<slug>.md` (human-readable) |

## How to Start

The feature name comes from `$ARGUMENTS`. If `$ARGUMENTS` is empty, check for
recent design docs in `docs/design/` and ask which one to decompose.

Confirm that both the design doc and the prototype directory exist before proceeding.
If either is missing, stop and explain — this skill depends on the planning skill's
output.

Announce: "I'm using the prototype-driven-task-decomposition skill to break down
the design doc into implementation tasks."

## Environment Setup

The schema validation step (Phase 3) requires `pydantic` to be importable. Rather
than activating a project venv (which doesn't carry across shell sessions in Claude
Code), use `uv` to run Python with the pydantic dependency:

```bash
uv run --with pydantic python -c "
import sys
sys.path.insert(0, '<path-to-skill>/scripts')
from task_schema import TaskDecomposition
d = TaskDecomposition.model_validate_json(open('tasks/<feature>/tasks.json').read())
print(f'Valid: {len(d.tasks)} tasks')
"
```

Check that `uv` is available early (e.g., `which uv`). If `uv` is not available,
fall back to `pip install pydantic` in a temporary venv or use the system Python
if pydantic is already installed.

## Phase 1: Design Doc Analysis

Read `references/analysis-guide.md` for detailed guidance, then:

1. **Read the full design doc.** Parse each section — Architecture Overview,
   Data Model, Dependencies, Testing Strategy, Containerization, Security Posture,
   Deployment Strategy.

2. **Inventory the prototype.** List the prototype's files and understand what
   each one demonstrates. These become the `prototype_references` in tasks.

3. **Identify component boundaries.** The Architecture Overview's "Components"
   section defines the natural task boundaries. Each component typically becomes
   one or more tasks.

4. **Map dependencies.** Determine which components depend on which. This drives
   task ordering. A component that other components import from must be built first.
   Include interface dependencies — if task B will import from a module created
   by task A, task B depends on task A even if it could technically be written
   without reading that file.

5. **Surface ambiguities.** Identify places where the design doc leaves room for
   interpretation — storage backend choices, naming conventions, scope boundaries,
   idempotency strategies. Collect these as explicit numbered questions.

6. **Propose the decomposition.** Present to the user:
   - How many tasks and in which phases
   - The dependency graph (which tasks block which)
   - Numbered questions for any ambiguities that need resolution
   - Any design doc sections that feel underspecified for task creation

**STOP.** Present the proposed decomposition outline and questions. Wait for the
user to answer the questions and confirm before generating the full task set.

## Phase 2: Task Generation

Read `references/task-writing-guide.md` for detailed guidance, then:

1. **Generate tasks** following the schema defined in `scripts/task_schema.py`.
   Every task must be self-contained — the implementing model receives only its
   task definition and access to the prototype and codebase. It does NOT see the
   full design doc or other tasks.

2. **Assign phases.** Use the `TaskPhase` enum to group tasks:
   - `scaffold` — Project structure, config files, dependency setup
   - `core` — Business logic, data models, core functionality
   - `integration` — Wiring components together, API endpoints, orchestration
   - `testing` — Test infrastructure, fixtures, integration tests
   - `infrastructure` — Dockerfile, CI/CD config, deployment

3. **Set dependencies.** A task's `depends_on` must list every task whose output
   files this task needs to exist. Over-specifying dependencies is safer than
   under-specifying — a missing dependency means a model tries to import something
   that doesn't exist yet. Include interface dependencies: if a task will import
   from another task's module in production, add the dependency so the implementing
   model can read the real module definition.

4. **Reference the prototype.** For each task, identify which prototype files
   demonstrate relevant patterns. Be specific about what to reference — "the API
   response parsing at lines 23-31" not "fetch.py".

5. **Write acceptance criteria.** Every task gets at minimum "lint passes" and
   any relevant test criteria. Add feature-specific criteria too — "endpoint
   returns 200 for valid input", "config loads from environment variables".

6. **Add security considerations** where relevant. Pull these from the design doc's
   Security Posture section, distributed to the specific tasks where each concern
   is actionable.

7. **Handle tasks without direct tests.** Some integration-phase tasks are hard
   to unit test and rely on downstream testing-phase tasks for verification. This
   is acceptable — give those tasks structural acceptance criteria and note in
   their description which testing task verifies them end-to-end.

## Phase 3: Validation and Output

Read `references/output-format.md` for detailed guidance on file formats, then:

1. **Validate the dependency graph.** Check for:
   - Circular dependencies (A depends on B depends on A)
   - Missing references (task depends on an ID that doesn't exist)
   - Orphan tasks (tasks nothing depends on that aren't leaf tasks)

2. **Validate against the PydanticAI schema.** Run the schema validation using
   `uv run --with pydantic` (see Environment Setup above). Fix any validation
   errors before writing the final output.

3. **Write `tasks/<feature-name>/tasks.json`.** This is the machine-readable
   output validated against the PydanticAI schema. It's the source of truth for
   the implementation pipeline.

4. **Write individual task markdown files.** Create one
   `tasks/<feature-name>/task-NN-<slug>.md` per task. These are a human-readable
   view for review and manual editing.

5. **Generate a summary.** Print a table showing: task ID, title, phase,
   dependencies, and file count. Include a pointer to the PydanticAI schema
   (`scripts/task_schema.py`) and the `uv run` validation command so the user
   can verify the output independently.

**STOP.** Present the task summary table and ask for review. If the user wants
changes, iterate on specific tasks. After approval, remind the user:
- `tasks.json` is the source of truth for the implementation pipeline
- Markdown files are a convenience view — edits there won't auto-sync to JSON
- The prototype directory is referenced but never modified
- The schema in `scripts/task_schema.py` can validate `tasks.json` independently

## Schema Reference

The canonical schema lives in `scripts/task_schema.py`. Here's what each task
captures at a glance:

| Field | Purpose |
|-------|---------|
| `id` | Unique identifier (e.g., `task-01`) |
| `title` | Action-oriented summary |
| `phase` | Execution grouping (scaffold → core → integration → testing → infrastructure) |
| `description` | Self-contained context for the implementing model |
| `depends_on` | Task IDs that must complete first |
| `files` | Files to create or modify, with descriptions |
| `prototype_references` | Specific prototype files/patterns to follow |
| `tests` | Tests that must pass (unit, integration, e2e) |
| `acceptance_criteria` | Verifiable completion conditions |
| `security_considerations` | Security concerns and mitigations |

## Principles

- **Tasks are self-contained.** The implementing model gets one task at a time.
  It has access to the prototype and the growing codebase, but not the design doc
  or other task definitions. Every task must include enough context to work alone.

- **Reference, don't copy.** Tasks point to prototype files for patterns. The
  implementing model reads those files directly. Don't reproduce prototype code
  in the task description — it goes stale.

- **Right-size for local models.** Each task should be completable in a single
  Aider session with a local model (Qwen/Codestral, ~30B parameters). If a task
  requires understanding multiple complex subsystems simultaneously, split it.
  If a task is just "create an empty config file", merge it with a related task.

- **Dependencies are explicit.** If task B imports a module created by task A,
  task B must list task A in `depends_on`. Implicit ordering via task numbers
  is not enough — the pipeline uses `depends_on` for topological sorting.
  Include interface dependencies so the implementing model can read the real
  module it depends on.

- **Security is distributed.** Don't create a standalone "security task". Instead,
  attach security considerations to the specific tasks where they're actionable.
  The model implementing the API client is the one that needs to know about input
  validation, not a separate security review task.
