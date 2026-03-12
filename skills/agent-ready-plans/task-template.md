# Task Document Template

Every task file follows this structure. The goal: a small model should be able to implement the component by reading only this one file — no other context needed. The task describes *what* to build and *what it should do*, not the exact code to write.

**Component tasks have no `## Files to Modify` or `## Wiring` section.** Component tasks create files only — they never touch shared orchestrating files (DAGs, registries, routers, dispatchers). Modifications to shared files are collected into dedicated wiring tasks that run after all components complete, and those wiring tasks are always deferred. See `references/writing-guide.md` § "Task Scope: Component Tasks vs Wiring Tasks".

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
- `exact/path/from/project/root/tests/test_module.py`

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

> Pre-written by Claude Code. **Do not modify this file.** Your implementation must make
> these tests pass without changing them.

` ` `[language]
# Complete test code authored by Claude Code during scaffold phase.
# Tests were validated against a stub implementation:
#   - Mutation gate passed (>80% mutation score)
#   - All tests fail against the stub for the right reasons (NotImplementedError /
#     wrong return value — not ImportError or fixture setup errors)
` ` `

## Dependencies

[What this component imports from prior tasks. Include the exact import path
and which task created it.]

- `from plugins.path.base import BaseClass` (Task 03)
- `from config.settings import Settings` (Task 02)

## Commit

` ` `bash
git add exact/path/to/module.py exact/path/to/tests/test_module.py
git commit -m "feat(scope): add component name"
` ` `

## Verification

- [ ] `module.py` exists with `ComponentName` class matching interface contract
- [ ] All tests in `## Tests` pass without modifying the test file
- [ ] Lint passes
- [ ] Tests pass
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
- Use in-memory SQLite fixtures for extractor tests

Available conftest fixtures (use these instead of writing your own mocks):
- `mock_drive_service` — pre-wired Google Drive API v3 mock with download support
- `mock_s3_client` — pre-wired boto3 S3 client mock with put_object capture
- `mock_pika_connection` — pre-wired pika.BlockingConnection mock with channel/publish

**Output constraint:** Respond with ONLY the file changes. Do not include
explanations, test commands, suggestions, or any conversational text.
```

**Too verbose (30+ lines about architecture the model doesn't need):** trim to essentials.

### Interface Contract

This is the most important section. It defines the public API that downstream tasks depend on. The small model must implement a class/function matching these signatures exactly.

**What to include:** Class name, inheritance, all public method signatures with type hints, class-level attributes, property definitions.

**What NOT to include:** Method bodies, private methods, import statements for standard library, internal implementation details.

### Behavior

Each bullet becomes a test the model writes. Be specific enough that there's one correct answer, but don't prescribe the test code. The model chooses its own fixtures, mock patterns, and assertion style.

### Tests

This section contains complete test code authored by Claude Code during the scaffold phase (Step 3b). It is not a placeholder — paste the actual validated test file here verbatim.

The test code was validated before task doc generation:
- **Mutation gate passed** (>80% mutation score against the stub)
- **All tests fail for the right reasons** against the stub (wrong return value / NotImplementedError — not import errors or fixture problems)

The small model must not modify this section. Its only job is to write the implementation that makes these tests pass.

### Dependencies

Tells the model what it can import from prior tasks. Include exact import paths — the model uses these verbatim.

### Why there is no Wiring or Files to Modify section

Component tasks do not wire themselves into shared files. Adding a new extractor to a DAG, registering a handler in a router, or appending to a registry are all modifications to shared orchestrating files — and shared file modifications belong exclusively in dedicated wiring tasks that run after all components are complete.

This prevents cascade failures: if wiring is inline with a component task, and the shared file's test is part of that task's gate, then a broken shared file fails every subsequent component task regardless of whether those components are individually correct. Separating wiring into its own deferred phase means each component is tested in complete isolation, and the wiring task is the only task that can affect shared-file test results.

If you find yourself writing a `## Files to Modify` or `## Wiring` section in a component task doc, stop — that content belongs in a deferred wiring task instead.
