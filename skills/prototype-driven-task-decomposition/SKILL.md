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

Tasks follow strict TDD discipline: for every component with testable logic,
a test task writes the tests first, then an implementation task writes the code
that makes them pass. A task never writes both tests and production code.

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
   a TDD pair: one test task + one implementation task.

4. **Map dependencies.** Determine which components depend on which. This drives
   task ordering. A component that other components import from must be built first.
   Include interface dependencies — if task B will import from a module created
   by task A, task B depends on task A even if it could technically be written
   without reading that file.

5. **Surface ambiguities.** Identify places where the design doc leaves room for
   interpretation — storage backend choices, naming conventions, scope boundaries,
   idempotency strategies. Collect these as explicit numbered questions.

6. **Propose the decomposition.** Present to the user:
   - How many tasks and in which phases (showing TDD pairs)
   - The dependency graph (which tasks block which)
   - Numbered questions for any ambiguities that need resolution
   - Any design doc sections that feel underspecified for task creation

**STOP.** Present the proposed decomposition outline and questions. Wait for the
user to answer the questions and confirm before generating the full task set.

## Phase 2: Task Generation

Read `references/task-writing-guide.md` for detailed guidance, then:

1. **Generate TDD task pairs** for every component with testable logic. Each pair
   consists of:
   - A **test task** (`task_type: "test"`) that writes the test file(s). It creates
     test files only — never production code. Its acceptance criteria include
     "tests are importable" and "tests fail because implementation does not exist."
   - An **implementation task** (`task_type: "implementation"`) that writes the
     production code. It creates production files only — never test files. It
     depends on its test task. Its acceptance criteria include "all tests pass."

   The test task always comes first in the dependency chain. The schema enforces
   this: an implementation task with tests must depend on at least one test task.

2. **Use `implementation` type for non-testable tasks** like scaffold setup,
   Dockerfile creation, or deployment config. These don't need a preceding
   test task.

3. **Assign phases.** Use the `TaskPhase` enum to group tasks:
   - `scaffold` — Project structure, config files, dependency setup
   - `core` — Business logic, data models, core functionality
   - `integration` — Wiring components together, API endpoints, orchestration
   - `testing` — Test infrastructure, fixtures, integration tests
   - `infrastructure` — Dockerfile, CI/CD config, deployment

4. **Set dependencies.** A task's `depends_on` must list every task whose output
   files this task needs to exist. Over-specifying dependencies is safer than
   under-specifying. Include interface dependencies: if a task will import
   from another task's module in production, add the dependency so the implementing
   model can read the real module definition. Implementation tasks must always
   depend on their corresponding test task.

5. **Reference the prototype.** For each task, identify which prototype files
   demonstrate relevant patterns. Be specific about what to reference — "the API
   response parsing at lines 23-31" not "fetch.py". Test tasks should reference
   prototype test files for fixture patterns and test structure.

6. **Write acceptance criteria.** Criteria differ by task type:
   - **Test tasks**: "test file is importable", "tests fail because implementation
     does not exist yet", "lint passes"
   - **Implementation tasks**: "all tests pass", plus feature-specific criteria,
     "lint passes"

7. **Add security considerations** where relevant. These go on implementation
   tasks (the ones writing the production code), not on test tasks.

## Phase 3: Validation and Output

Read `references/output-format.md` for detailed guidance on file formats, then:

1. **Validate the dependency graph.** Check for:
   - Circular dependencies (A depends on B depends on A)
   - Missing references (task depends on an ID that doesn't exist)
   - TDD violations (implementation task with tests that doesn't depend on a
     test task)

2. **Validate against the PydanticAI schema.** Run the schema validation using
   `uv run --with pydantic` (see Environment Setup above). Fix any validation
   errors before writing the final output.

3. **Write `tasks/<feature-name>/tasks.json`.** This is the machine-readable
   output validated against the PydanticAI schema. It's the source of truth for
   the implementation pipeline.

4. **Write individual task markdown files.** Create one
   `tasks/<feature-name>/task-NN-<slug>.md` per task. These are a human-readable
   view for review and manual editing.

5. **Generate a summary.** Print a table showing: task ID, title, type, phase,
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
| `task_type` | `test` (writes tests) or `implementation` (writes code, runs tests) |
| `phase` | Execution grouping (scaffold → core → integration → testing → infrastructure) |
| `description` | Self-contained context for the implementing model |
| `depends_on` | Task IDs that must complete first |
| `files` | Files to create or modify, with descriptions |
| `prototype_references` | Specific prototype files/patterns to follow |
| `tests` | Test tasks: cases to write. Implementation tasks: existing tests that must pass |
| `acceptance_criteria` | Verifiable completion conditions |
| `security_considerations` | Security concerns and mitigations |

## Principles

- **Tests first, always.** Every component with testable logic gets a test task
  before its implementation task. The test task writes tests that fail (because
  the implementation doesn't exist yet). The implementation task makes them pass.
  A task never writes both tests and production code.

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
  attach security considerations to the implementation tasks where each concern
  is actionable. The model implementing the API client is the one that needs to
  know about input validation, not a separate security review task.
