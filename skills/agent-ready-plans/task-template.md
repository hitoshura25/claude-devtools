# Task Document Template

Every task file follows this structure. A small model should be able to implement the component by reading only this file plus the pre-written test file on disk.

**Component tasks create files only — they never modify shared files** (DAGs, registries, routers). Modifications to shared files belong in dedicated wiring tasks. See `references/writing-guide.md` § "Task Scope".

---

```markdown
# Task [NN]: [Task Title]

> **Phase:** [Phase Name]
> **Original Task:** [X.Y from plan]
> **Complexity:** [simple | moderate | complex]

## Project Context

[Brief context block — 10-15 lines max. Same across all tasks in a plan.
Include: what the project does, tech stack, directory structure, lint/test commands,
conventions, and any environment constraints (e.g., "Airflow not installed, conftest mocks it").]

**Output constraint:** Respond with ONLY the file changes. Do not include
explanations, test commands, suggestions, or any conversational text.

## Objective

[1-2 sentences: what this task accomplishes and why it matters to the system.]

## Prerequisites

[Files from prior tasks that must exist. For human reference — the runner executes sequentially.]

- `path/to/file-from-earlier-task.py` (created in Task NN-1)

## Files to Create

- `exact/path/from/project/root/module.py`

## Interface Contract

[The public API the implementation must expose. Downstream tasks import these
names, so class names and method signatures must match exactly.]

` ` `python
class ComponentName(BaseClass):
    """One-line description."""

    some_attribute: str  # Class-level attribute

    def method_one(self, param: ParamType) -> ReturnType:
        """What this method does — not how."""

    def method_two(self, param: ParamType) -> ReturnType:
        """What this method does — not how."""
` ` `

## Behavior

[Concrete requirements the implementation must satisfy. Each becomes a test.]

- [Specific behavioral requirement]
- [Edge case behavior]
- [Error handling behavior]
- [Constraint — e.g., "Must not make real network connections"]

## Tests

> Pre-written by Claude Code and validated against stubs. The test file already
> exists on disk — **do not modify it**. Implement the code to make it pass.

**Test file:** `exact/path/from/project/root/tests/test_module.py`

## Dependencies

[What this component imports from prior tasks. Include the exact import path
and which task created it.]

- `from plugins.path.base import BaseClass` (Task 03)
- `from config.settings import Settings` (Task 02)

## Commit

` ` `bash
git add exact/path/to/module.py
git commit -m "feat(scope): add component name"
` ` `

## Verification

- [ ] `module.py` exists with `ComponentName` class matching interface contract
- [ ] All tests in the test file pass without modifying the test file
- [ ] Lint passes
```

---

## Section Notes

### Project Context

Extracted once from the design doc, repeated verbatim in every task. Keep it tight — it eats into the small model's context window.

Always include:
- **Import convention** (e.g., `from plugins.*` not `from services.*`) — small models guess wrong import paths when this is implicit
- **Available conftest fixtures** — so the model uses pre-wired mocks instead of writing its own

**Good:**
```
This service downloads Health Connect exports from Google Drive, parses the
SQLite database, and feeds typed records into MinIO + RabbitMQ.

Tech stack: Python 3.11, Apache Airflow 2.8 (mocked), pydantic-settings, pytest, structlog
Service root: services/airflow-ingestion/
Import convention: use `from plugins.*` not `from services.*` — pythonpath is set to the service root
Lint: ./docs/plans/airflow-google-drive-ingestion-tasks/lint.sh (from project root)
Test: cd services/airflow-ingestion && uv run pytest -x -q
Conventions: TDD, abstract base classes, snake_case files, PascalCase classes

Testing constraints:
- Airflow is NOT installed — conftest.py patches airflow.* into sys.modules at collection time
- No real connections to external services in tests

Available conftest fixtures (use these instead of writing your own mocks):
- `mock_drive_service` — pre-wired Google Drive API v3 mock with download support
- `mock_s3_client` — pre-wired boto3 S3 client mock with put_object capture
- `mock_pika_connection` — pre-wired pika.BlockingConnection mock with channel/publish

**Output constraint:** Respond with ONLY the file changes. Do not include
explanations, test commands, suggestions, or any conversational text.
```

**Too verbose (30+ lines about architecture the model doesn't need):** trim to essentials.

### Interface Contract

Defines the public API downstream tasks depend on. Class/function names and method signatures must match exactly.

**Include:** Class name, inheritance, all public method signatures with type hints, class-level attributes, property definitions.

**Exclude:** Method bodies, private methods, standard library imports, implementation details.

### Behavior

Each bullet is a concrete requirement the implementation must satisfy. Be specific enough that there's one correct answer, but don't prescribe how to test it — tests are pre-written.

### Tests

This section references the pre-written test file by its on-disk path. The test file was written by Claude Code during Step 3b and validated through the Three-Layer Validation Gate (lint, mutation, correct failure mode). It is the single source of truth.

The small model reads the test file directly from disk. The task doc does not embed a copy — embedding creates a second source of truth that can diverge from the validated file. The model implements the code to make the on-disk tests pass.

### Dependencies

Tells the model what it can import from prior tasks. Include exact import paths — the model uses these verbatim.

### Why there is no Files to Modify section

Component tasks do not wire themselves into shared files. Adding an extractor to a DAG, registering a handler in a router, or appending to a registry all modify shared orchestrating files — these belong exclusively in dedicated wiring tasks that run after all components are complete.

This prevents cascade failures: a broken shared file in a component task would fail every subsequent component's test gate, even when those components are individually correct.
