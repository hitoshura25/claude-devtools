# Plan Format

The implementation plan is a single markdown file that describes how to build a feature as a series of interface specs. It's designed to be consumed by the `devtools:agent-ready-plans` skill, which turns each task into a standalone spec file for a small model to implement. The plan defines *what* each component does and how components connect — the small model decides *how* to write the code.

## Why Specs, Not Code

Earlier versions of this plan format included complete code (test files and implementation) for every task. This repeatedly produced subtle bugs that small models couldn't fix: mock scopes that exited before use, collection-time import failures, metaprogramming patterns the model couldn't reason about. The plan author would get a detail wrong, and the small model would spend all its reflections trying to debug code it didn't write.

Spec-based plans separate responsibilities cleanly: the plan defines interface contracts and behavioral scenarios, Claude Code authors the tests against stubs and validates them with a mutation gate, and the small model writes only the implementation. The plan's job is to define the interface contract and test scenarios precisely enough that Claude Code can write tests that actually catch bugs — and that the small model can't drift from the architecture.

## Writing Strategy

Spec-based plans are much shorter than code-based plans (~800-1200 lines vs ~3000+). Most can be written in 2-3 tool calls. For larger plans:

1. Write the header + first 2-3 phases in the initial file creation
2. Append remaining phases using edit/append operations
3. Keep each chunk aligned to phase boundaries

## Document Structure

```markdown
# [Feature Name] Implementation Plan

> **Downstream:** This plan feeds into `devtools:agent-ready-plans` for task
> decomposition. Each task below becomes a standalone spec file for a local
> coding model to implement.

**Goal:** [One sentence — what this builds and why]

**Design doc:** `docs/plans/YYYY-MM-DD-feature-name-design.md`

**Architecture:** [2-3 sentences about the approach — enough context for
someone unfamiliar with the codebase to understand the shape of the system]

**Tech stack:** [Key languages, frameworks, libraries]

**Service root:** [Path from project root, e.g., `services/airflow-ingestion/`]

**Testing conventions:**
- [How to run tests, e.g., `uv run pytest` from service root]
- [Key testing patterns, e.g., "Airflow is NOT installed — conftest patches sys.modules at collection time"]
- [Fixture patterns, e.g., "Use in-memory SQLite for extractor tests"]

**Scaffold (created by Claude Code before task execution):**
- [List of files Claude Code creates directly: pyproject.toml, conftest.py, lint config, __init__.py files]

**External dependency mock fixtures (created in conftest.py by Claude Code):**
- [List each fixture name, what it mocks, and what it exposes to tests]
- [e.g., `mock_drive_service` — Google Drive API v3 with fluent chain + download buffer simulation]
- [e.g., `mock_s3_client` — boto3 S3 client with put_object capture]
- [Include only for external clients with complex mock patterns — simple libraries don't need fixtures]

---

## Phase 1: [Phase Name]

### Task 1.1: [Component Name]

[Task content — see Task Template below]

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

Each task defines an interface contract that the small model implements. The precision of the contract determines whether the model produces correct code — vague specs produce incompatible components, precise specs produce a working system.

**Tests and implementation belong in the same task.** Claude Code writes the test file during the scaffold phase and embeds it in the task doc. The small model implements against it. Never split the test file into a separate task from its implementation — the small model needs both to do its job.

```markdown
### Task X.Y: [Component Name]

**Files:**
- Create: `exact/path/from/project/root/file.py`
- Create: `tests/exact/path/test_file.py`
- Modify: `exact/path/to/existing.py` (add new entry to REGISTRY list)

**Interface:**

` ` `python
class ComponentName(BaseClass):
    """One-line description."""

    def method_one(self, param: Type) -> ReturnType:
        """What this does, not how."""

    def method_two(self, param: Type) -> ReturnType:
        """What this does, not how."""
` ` `

**Behavior:**
- [Concrete behavioral requirement — e.g., "Returns only records with last_modified_time > watermark_ms"]
- [Edge case — e.g., "Returns empty list when no records match"]
- [Constraint — e.g., "Must not make real network connections; mock at pika/boto3 boundary"]

**Test scenarios:**
- [Scenario name]: [What to set up] → [What to assert]
- [Scenario name]: [What to set up] → [What to assert]
- [Scenario name]: [What to set up] → [What to assert]

**Dependencies:**
- Imports `BaseClass` from `plugins/path/base.py` (created in Task X.Y)
- [Any other cross-task dependencies]

**Wiring:**
- Add import and append `ComponentName()` to `REGISTRY` in `path/to/registry.py`
```

**Note:** The triple backticks above are escaped for nesting. Use real markdown fences in the actual plan.

## Writing Interface Contracts

The interface block is the most important part of the task. It defines class names, method signatures, parameter types, and return types. The small model must match these exactly so that downstream tasks can import and use the component.

**Include:**
- Class name and inheritance (what it extends)
- All public method signatures with type hints
- Property definitions if used
- Class-level attributes (e.g., `record_type: str`)

**Do not include:**
- Method bodies (the model writes these)
- Private/internal methods (the model decides its own internal structure)
- Import statements for standard library (the model knows these)

**Do include in Dependencies:**
- Import paths for project-internal modules the component uses
- Which task created each dependency

## Writing Behavior Specs

Behavior specs replace the complete test code from the old format. They tell the model *what* to test without prescribing *how* to test it. The model writes its own fixtures, mocks, and assertions.

**Good behavior specs:**
```
- Filters records where last_modified_time > watermark_ms
- Returns all records when watermark_ms is 0
- Returns empty list when no records are newer than watermark
- max_last_modified() returns the highest last_modified_ms across records
- max_last_modified() returns 0 for an empty list
```

**Bad behavior specs (too vague):**
```
- Works correctly
- Handles edge cases
- Tests pass
```

**Bad behavior specs (prescribing implementation):**
```
- Use @pytest.fixture with sqlite3.connect(":memory:")
- Create table with columns (value INTEGER, last_modified_time INTEGER)
- Insert rows (10, 1000), (20, 2000), (30, 3000)
- Assert len(results) == 2
```

The sweet spot: describe *what the code does* precisely enough that any correct implementation would pass the tests, without dictating the test code itself.

## Writing Test Scenarios

Test scenarios are the input Claude Code uses to write the actual test code during the agent-ready-plans scaffold phase (Step 3b). They are not instructions for the small model — the small model never sees prose scenarios, only the finished test file embedded in the task doc.

Write scenarios precise enough that Claude Code can derive the correct assertions from them. Each scenario has a name, a setup, and an unambiguous expected outcome.

```
**Test scenarios:**
- watermark_filtering: In-memory SQLite with 3 rows at times 1000/2000/3000, extract with watermark=1500 → returns only rows at 2000 and 3000
- watermark_zero: Same fixture, watermark=0 → returns all 3 rows
- no_new_records: Same fixture, watermark=9999 → returns empty list
- max_watermark: Extract all rows → max_last_modified returns 3000
- max_watermark_empty: No rows extracted → max_last_modified returns 0
```

**Key rules:**
- Name each scenario (Claude Code uses these as test function names)
- Specify concrete test data where it matters for correctness — exact values, not "some rows"
- State the expected outcome unambiguously — exact return values, not "correct results"
- Cover boundary conditions explicitly (e.g., watermark equal to a row's timestamp, not just clearly above/below)
- For external services, reference the conftest fixture by name (e.g., "use `mock_drive_service` fixture, set file_bytes to b'ZIP DATA'")
- Include at least one error/empty case per component

## Environment and Mocking Constraints

When a project has unusual testing requirements (like Airflow not being installed), state these as constraints the model must satisfy, not as implementation instructions.

**Good:**
```
**Testing constraints:**
- Airflow is NOT installed in the dev environment
- conftest.py provides an autouse fixture that patches airflow.* into sys.modules before collection
- Your implementation can import from airflow at module level — the conftest handles it
- No real connections to external services in tests

**Available conftest fixtures** (use these instead of writing your own mocks):
- `mock_drive_service` — pre-wired Google Drive API v3 mock with download support
- `mock_s3_client` — pre-wired boto3 S3 client mock with put_object capture
- `mock_pika_connection` — pre-wired pika.BlockingConnection mock with channel/publish
```

**Bad (prescribing mock implementation):**
```
Use this exact mock pattern:
with patch("plugins.health_connect.rabbitmq_publisher.pika") as mock_pika:
    mock_conn = MagicMock()
    ...
```

The first tells the model what constraints to satisfy and what fixtures are available. The second gives it code that might have a bug (like a context manager that exits too early).

The key insight: external service mocks (Google APIs, boto3, pika) require understanding library internals that small models don't have. By providing pre-wired fixtures in conftest.py, the plan shifts mock complexity from the small model to Claude Code. The plan's test scenarios can then reference fixtures by name: "Use `mock_drive_service` fixture, set file_bytes to b'ZIP DATA', call download_file, assert result matches."

## Phasing Guidelines

Group tasks into phases that build on each other. Earlier phases create foundations, later phases add features that depend on them.

**Good phasing:**
```
Phase 1: Project Scaffolding (Claude Code creates directly — not a task)
Phase 2: Core Abstractions (base classes, shared types, settings)
Phase 3: Infrastructure Clients (external service wrappers)
Phase 4: Primary Components (main business logic modules)
Phase 5: Orchestration (DAG assembly, router setup, dispatcher config)
Phase 6: Remaining Components (additional implementations of Phase 2 patterns)
Phase 7: Docker / Deployment
Phase 8: Integration Tests (deferred — depends on real interfaces)
```

**Phase 1 is special:** The project scaffold (pyproject.toml, conftest.py, `__init__.py` files, lint config) is created directly by Claude Code in the agent-ready-plans setup step — not delegated to a small model. The plan should list what the scaffold contains so Claude Code knows what to create, but it's not a numbered task that produces a task doc.

**The critical ordering rule:** Orchestration tasks (Phase 5) that create registries, routers, or dispatchers should come *after* the components they initially register but *before* later phases that add more components. Phase 5 lists the initial set, Phase 6 tasks each include a wiring step to register themselves.

**When a later-phase task creates something that must be registered in an earlier-phase component,** the later task's "Files" section must include a "Modify" entry and a "Wiring" section:

```markdown
### Task 6.3: Oxygen Saturation Extractor

**Files:**
- Create: `plugins/record_extractors/oxygen_saturation_extractor.py`
- Create: `tests/test_record_extractors/test_oxygen_saturation_extractor.py`
- Modify: `dags/health_connect_ingestion.py` (add OxygenSaturationExtractor to EXTRACTORS list and import)

**Wiring:**
- Add `from ...oxygen_saturation_extractor import OxygenSaturationExtractor` to DAG imports
- Append `OxygenSaturationExtractor()` to `EXTRACTORS` list
```

This is the single most common source of decomposition bugs. See `wiring-completeness.md` for the full checklist.

## Deferred Tasks

Some tasks can't be specified precisely until the implementation tasks have run, because they depend on the exact function signatures, class hierarchies, and import paths that the small model produces. Integration tests are the primary example.

Mark these as deferred in the plan. Include enough detail for Claude Code to generate them later:
- What components are being integrated
- What scenarios to test (happy path, error cases, edge cases)
- Which tasks they depend on
- General assertions (without exact function signatures)

## Sizing Guidance

Spec-based tasks are naturally shorter than code-based tasks. Most produce task docs well under the ~2000 token target. If a task has a complex interface with many methods:

- **Simple tasks** (scaffolding, config, settings): 1 task per file group
- **Moderate tasks** (one class + its tests): 1 task per component
- **Complex tasks** (multiple interacting files): split by responsibility — e.g., "DAG test infrastructure" and "DAG implementation" — but always keep test scenarios with the component they test

If a task has more than 3 files in its "Create" list, consider splitting it. But always keep test scenarios together with the implementation they verify.
