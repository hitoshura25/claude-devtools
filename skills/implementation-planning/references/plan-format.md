# Plan Format

The implementation plan is a single markdown file that fully describes how to build a feature, task by task. It's designed to be consumed by the `devtools:agent-ready-plans` skill, which turns each task into a standalone file for a small model. Everything in the plan must be explicit enough that someone with zero context about the codebase could execute it.

## Writing Strategy

Plans with complete code are large — a 20-task plan can easily be 3000+ lines. Do not attempt to write the entire plan in one tool call; this will hit output token limits. Instead:

1. Write the header + first 2-3 phases in the initial file creation
2. Append remaining phases one at a time using file edit/append operations
3. Keep each chunk aligned to phase boundaries — never split a task across chunks

## Document Structure

```markdown
# [Feature Name] Implementation Plan

> **Downstream:** This plan feeds into `devtools:agent-ready-plans` for task
> decomposition. Each task below becomes a standalone file for a local coding model.

**Goal:** [One sentence — what this builds and why]

**Design doc:** `docs/plans/YYYY-MM-DD-feature-name-design.md`

**Architecture:** [2-3 sentences about the approach — enough context for
someone unfamiliar with the codebase to understand the shape of the system]

**Tech stack:** [Key languages, frameworks, libraries]

**Service root:** [Path from project root, e.g., `services/airflow-ingestion/`]

---

## Phase 1: [Phase Name]

### Task 1.1: [Component Name]

[Task content — see Task Template below]

### Task 1.2: [Next Component]

...

## Phase 2: [Phase Name]

### Task 2.1: ...

...

## Phase N: Integration Tests (deferred)

### Task N.1: [Integration Test Name] *(deferred)*

**Deferred:** Generate after implementation tasks complete — tests depend
on real function signatures and import paths from earlier tasks.

**What to test:**
- [Description of integration scenarios]
- [Components being integrated]
- [Key assertions to verify]

**Depends on:** Tasks X.Y, X.Z, ...
```

## Task Template

Each task follows this structure. The precision here directly determines whether the small model succeeds or fails — every field matters.

```markdown
### Task X.Y: [Component Name]

**Files:**
- Create: `exact/path/from/project/root/file.py`
- Create: `tests/exact/path/test_file.py`
- Modify: `exact/path/to/existing.py` (add new entry to REGISTRY list)

**Step 1: Write the failing test**

` ` `python
# tests/exact/path/test_file.py
"""Tests for component name."""

import pytest


class TestComponentName:
    def test_specific_behavior(self):
        result = function(input)
        assert result == expected
` ` `

**Step 2: Run test — expect FAIL**

` ` `bash
cd services/service-name && python -m pytest tests/test_file.py -x -q
# Expected: FAIL — ModuleNotFoundError or ImportError
` ` `

**Step 3: Implement**

` ` `python
# exact/path/from/project/root/file.py
"""Module docstring."""


def function(input):
    """Docstring."""
    return expected
` ` `

**Step 4: Run test — expect PASS**

` ` `bash
cd services/service-name && python -m pytest tests/test_file.py -x -q
# Expected: PASS
` ` `

**Step 5: Commit**

` ` `bash
git add exact/path/file.py tests/exact/path/test_file.py
git commit -m "feat(scope): add component name"
` ` `
```

**Note:** The triple backticks above are escaped for nesting. Use real markdown fences in the actual plan.

## Writing the Code Blocks

The code in the plan ends up verbatim in task docs. Treat it as production code, not pseudocode:

- **Complete implementations** — no "add validation logic here" or "implement the rest." Every function body must be filled in. If the implementation is complex, that's fine — write it out. Small models are good at creating files from complete examples but terrible at filling in blanks.

- **Lint-clean** — the task runner enables auto-lint. Code with style violations (unused imports, wrong import order, wrong string quoting) causes the small model to enter fix loops. Write the code the way the linter wants it.

- **Test-first always** — the test file appears before the implementation in every task. This is the TDD ordering the task runner expects.

## Writing Effective Tests

Tests in the plan should verify that *your code* transforms input into output correctly — not that standard library functions work. The difference matters because when a test fails, the small model needs to know whether to fix the test or the implementation. Tests that assert business logic against fixture data are unambiguous; tests that re-verify library behavior with manually computed constants are fragile and error-prone.

**Test your code, not the language.** If a function is a thin wrapper around a standard library call (timestamp formatting, JSON serialization, base64 encoding), don't write a test that hardcodes the expected output of that library call. You'll end up doing the computation by hand and getting it wrong. Instead, test the wrapper in context — as part of a larger flow where the input comes from a test fixture and the output is checked structurally.

**Use fixture data as the source of truth.** Build a test fixture (an in-memory SQLite database, a mock API response, a sample message) that represents real-world input. Run your code against it. Assert properties of the output that reflect your business logic: the right number of records, the right fields present, values matching what you put into the fixture. The fixture is data you control, so the expected values are known by construction — not computed by hand.

**Example — testing an extractor:**
```python
@pytest.fixture
def sample_db():
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE steps_table (start_time INTEGER, end_time INTEGER, count INTEGER)")
    conn.execute("INSERT INTO steps_table VALUES (1000, 2000, 150)")
    conn.execute("INSERT INTO steps_table VALUES (3000, 4000, 200)")
    yield conn
    conn.close()

def test_extract_returns_records_above_watermark(sample_db):
    extractor = StepsExtractor()
    results = extractor.extract(sample_db, watermark_ms=1500)
    # Verifies business logic: only records with start_time > watermark
    assert len(results) == 1
    assert results[0]["count"] == 200
```

Notice what this test does *not* do: it doesn't hardcode a formatted timestamp string that someone computed by hand. The expected value (`200`) comes directly from the fixture data (`INSERT INTO ... 200`). The assertion verifies that the watermark filter works — which is the actual business logic.

**When hardcoded expected values are unavoidable,** keep them trivially verifiable. Use epoch `0` (which is `1970-01-01T00:00:00+00:00` — everyone knows this), or small round numbers, or values copied directly from real data sources. Avoid hand-computing conversions for large epoch timestamps, hex encodings, or hash digests — these are exactly the values that are easy to get wrong during planning.

**Mock at the boundary, not the internals.** Mock external services (Google Drive API, MinIO, RabbitMQ) but let internal logic run for real. This tests your actual code paths rather than testing that mocks return what you told them to return.

## Phasing Guidelines

Group tasks into phases that build on each other. Earlier phases create foundations, later phases add features that depend on them.

**Good phasing:**
```
Phase 1: Project Scaffolding (directory structure, config, requirements)
Phase 2: Core Abstractions (base classes, shared types, settings)
Phase 3: Primary Components (the main business logic modules)
Phase 4: Infrastructure Integration (writers, publishers, clients)
Phase 5: Orchestration (DAG assembly, router setup, dispatcher config)
Phase 6: Remaining Components (additional implementations of Phase 3 patterns)
Phase 7: Integration Tests (deferred — depends on real interfaces)
```

**The critical ordering rule:** Orchestration tasks (Phase 5) that create registries, routers, or dispatchers should come *after* the components they initially register but *before* later phases that add more components. This way Phase 5 lists the initial set, and Phase 6 tasks each include a step to register themselves. If orchestration comes last, it has to know about everything — which works fine for the plan, but makes the task doc enormous and brittle.

**When a later-phase task creates something that must be registered in an earlier-phase component,** the later task's "Files" section must include a "Modify" entry for the registry file:

```markdown
### Task 6.3: Oxygen Saturation Extractor

**Files:**
- Create: `plugins/record_extractors/oxygen_saturation_extractor.py`
- Create: `tests/test_record_extractors/test_oxygen_saturation_extractor.py`
- Modify: `dags/health_connect_ingestion.py` (add OxygenSaturationExtractor to EXTRACTORS list and import)
```

This is the single most common source of decomposition bugs. See `wiring-completeness.md` for the full checklist.

## Deferred Tasks

Some tasks can't be written precisely until the implementation tasks have run, because they depend on the exact function signatures, class hierarchies, and import paths that the small model produces. Integration tests are the primary example — they call functions from multiple modules and mock at the boundaries between them.

Mark these as deferred in the plan. Include enough detail for Claude Code to generate them later:
- What components are being integrated
- What scenarios to test (happy path, error cases, edge cases)
- Which tasks they depend on
- General assertions (without exact function signatures)

The agent-ready-plans skill will create manifest entries for deferred tasks but skip generating the actual task doc files until after the implementation run completes.

## Sizing Guidance

Aim for tasks that produce task docs under ~2000 tokens when decomposed. A good rule of thumb:

- **Simple tasks** (scaffolding, config, requirements): 1 task per file group
- **Moderate tasks** (one class + its tests): 1 task per component
- **Complex tasks** (multiple interacting files): split into sub-tasks (e.g., 5.3a for tests, 5.3b for implementation)

If a task has more than 3 files in its "Create" list, consider splitting it.
