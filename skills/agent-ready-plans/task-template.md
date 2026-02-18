# Task Document Template

Every task file follows this structure. The goal: a small model should be able to execute the task by reading only this one file — no other context needed.

---

```markdown
# Task [NN]: [Task Title]

> **Phase:** [Phase Name]
> **Original Task:** [X.Y from plan]
> **Complexity:** [simple | moderate | complex]

## Project Context

[Brief context block — 10-15 lines max. Same across all tasks in a plan.
Include: what the project does, tech stack, directory structure, lint/test commands, conventions.]

## Objective

[1-2 sentences: what this task accomplishes and why.]

## Prerequisites

[Files from prior tasks that must exist. For human reference — the runner executes sequentially.]

- `path/to/file-from-earlier-task.py` (created in Task NN-1)

## Files to Create

[Listed up front so aider knows which files to track.]

- `exact/path/from/project/root/file.py`
- `exact/path/from/project/root/test_file.py`

## Files to Modify

[If modifying existing files instead of creating new ones.]

- `exact/path/to/existing.py` (lines ~120-135)

## Instructions

### Step 1: [Verb phrase — e.g. "Create the test file"]

Create `exact/path/to/test_file.py` with this content:

\```python
# exact/path/to/test_file.py
"""Tests for the specific module."""
import pytest

class TestSpecificBehavior:
    def test_does_the_thing(self):
        from module.path import SpecificClass
        result = SpecificClass().do_thing("input")
        assert result == "expected_output"
\```

### Step 2: [Verb phrase — e.g. "Create the implementation"]

Create `exact/path/to/file.py` with this content:

\```python
# exact/path/to/file.py
"""Module for specific functionality."""

class SpecificClass:
    def do_thing(self, input: str) -> str:
        return "expected_output"
\```

### Step 3: Commit

\```bash
git add exact/path/to/test_file.py exact/path/to/file.py
git commit -m "feat(scope): add specific feature"
\```

## Verification

- [ ] File exists: `exact/path/to/file.py`
- [ ] File exists: `exact/path/to/test_file.py`
- [ ] Lint passes (auto-lint verifies via runner)
- [ ] Tests pass (auto-test verifies via runner)
```

---

## Section Notes

### Project Context

Extracted once from the design doc, repeated verbatim in every task. Keep it tight — it eats into the small model's context window.

**Good:**
```
This project adds an Apache Airflow service that downloads Health Connect
exports from Google Drive, parses the SQLite database, and feeds records
into an existing MinIO + RabbitMQ pipeline.

Tech stack: Python 3.11, Apache Airflow 2.8, Pydantic, pytest, structlog
Directory: services/airflow-ingestion/
Lint: ruff check .
Test: cd services/airflow-ingestion && python -m pytest -x -q
Patterns: TDD (test first), Pydantic Settings, abstract base classes
Naming: snake_case files, PascalCase classes, conventional commits
```

**Too verbose (30+ lines about architecture the model doesn't need):** trim to essentials.

### Files to Create / Modify

Listed explicitly so aider's file-tracking knows what's in scope. Aider performs best when it knows upfront which files it will touch.

### Instructions

Each step is a single action with a verb-phrase title. Code blocks must be complete — no `...`, `# TODO`, or "implement similar to Task 3.1". The small model needs the actual code, not instructions to figure it out.

### Verification

Simplified because `--auto-lint` and `--auto-test` handle validation automatically. The checklist is a quick human sanity check between tasks.
