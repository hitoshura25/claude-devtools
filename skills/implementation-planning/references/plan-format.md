# Plan Format

The implementation plan is a single markdown file that describes how to build a feature as a series of interface specs. It's designed to be consumed by the `devtools:agent-ready-plans` skill, which turns each task into a standalone spec file for a small model to implement. The plan defines *what* each component does and how components connect — the small model decides *how* to write the code.

## Why Specs, Not Code

Earlier versions of this plan format included complete code (test files and implementation) for every task. This repeatedly produced subtle bugs that small models couldn't fix: mock scopes that exited before use, collection-time import failures, metaprogramming patterns the model couldn't reason about. The plan author would get a detail wrong, and the small model would spend all its reflections trying to debug code it didn't write.

Spec-based plans separate responsibilities cleanly: the plan defines interface contracts and behavioral scenarios, Claude Code authors the tests against stubs and validates them with a mutation gate, and the small model writes only the implementation. The plan's job is to define the interface contract and test scenarios precisely enough that Claude Code can write tests that actually catch bugs — and that the small model can't drift from the architecture.

## Writing Strategy

Spec-based plans are much shorter than code-based plans. Most can be written in 2-3 tool calls. For larger plans:

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

**Architecture:** [2-3 sentences about the approach]

**Tech stack:** [Key languages, frameworks, libraries]

**Service root:** [Path from project root, e.g., `services/my-service/`]

**Testing conventions:**
- [How to run tests]
- [Key testing patterns, e.g., "FrameworkX is NOT installed — test setup stubs its imports"]
- [Fixture patterns]

**Scaffold (created by Claude Code before task execution):**
- [List of files Claude Code creates directly: config, test setup, package structure]

**External dependency mock fixtures (created in test setup by Claude Code):**
- [List each fixture name, what it mocks, and what it exposes to tests]
- [Include only for external clients with complex mock patterns]

---

## Phase 1: [Phase Name]

### Task 1.1: [Component Name]

[Task content — see Task Template below]

...

## Phase N: Wiring

### Task N.1: [Wire Components into Orchestrator]

**Modifies:** `path/to/orchestrator.ext`

**What to wire:**
- `ComponentA` from `path/to/component_a.ext` (Task X.Y)
- `ComponentB` from `path/to/component_b.ext` (Task X.Z)

**Behavior:**
- [What the orchestrator does after all components are registered]
- [Any ordering constraints]

**Test scenarios:**
- [import_integrity]: All listed component classes are importable from their specified paths
- [orchestrator_behavior]: [What to assert about the assembled system]

**Depends on:** Tasks X.Y, X.Z, ...

## Phase N+1: Deployment

### Task N+1.1: [Service Name] Docker Deployment

**Files:**
- Create: `services/my-service/Dockerfile`
- Create: `services/my-service/deployment/service.compose.yml`
- Create: `services/my-service/deployment/service.test.compose.yml`

**Behavior:**
- [Base image family and language version requirement — e.g. "Apache Airflow with Python 3.11". Do NOT specify an exact tag here; Claude Code verifies the actual tag via `docker manifest inspect` during task-doc authoring and writes the verified tag into the task doc's Dockerfile spec.]
- [Installed dependencies, entrypoint command]
- [Environment variables the container reads]
- [Port the service listens on and health check endpoint]
- Production compose (`service.compose.yml`) connects to the shared platform network and assumes dependencies (MinIO, RabbitMQ, etc.) are pre-running
- Test compose (`service.test.compose.yml`) is fully self-contained: includes the service AND all dependencies it needs as local services on a local bridge network — no external services required to run the smoke test

**Test scenarios:**
- [smoke_test]: Container builds and starts; health endpoint returns HTTP 200 within timeout

**Depends on:** Task N.1

## Phase N+2: Integration Tests

### Task N+2.1: [Integration Test Name]

**Requires services:** [e.g., minio, rabbitmq — live containers needed at runtime]

**What to test:**
- [End-to-end scenario descriptions]
- [Deduplication/re-run behavior]

**Depends on:** Task N+1.1
```

## Task Template

Each task defines an interface contract that the small model implements. The precision of the contract determines whether the model produces correct code.

**Tests and implementation belong in the same task.** Claude Code writes the test file during the scaffold phase and saves it to disk. The task doc references the test file by path — it does not embed a copy. The small model reads the test file directly and implements the code to pass it. Never split the test file into a separate task from its implementation.

**Component tasks only create files — they never modify shared files.** No `Modify:` entries in component tasks. Wiring (adding to a registry, DAG, router, or dispatcher) is always a separate, dedicated task that runs after all components are complete. See § "Phasing Guidelines" below.

```markdown
### Task X.Y: [Component Name]

**Files:**
- Create: `exact/path/from/project/root/component.ext`
- Create: `tests/exact/path/test_component.ext`

**Interface:**

[language code block]
class ComponentName extends BaseClass {
  methodOne(param: Type): ReturnType  // what this does, not how
  methodTwo(param: Type): ReturnType  // what this does, not how
}
[end code block]

**Behavior:**
- [Concrete behavioral requirement]
- [Edge case]
- [Constraint — e.g., "Must not make real network connections"]

**Test scenarios:**
- [Scenario name]: [What to set up] → [What to assert]
- [Scenario name]: [What to set up] → [What to assert]

**Dependencies:**
- Imports `BaseClass` from `path/to/base.ext` (created in Task X.Y)
```

Note the absence of a `Wiring:` section. Component tasks do not touch orchestrating files. The model creates its component and its tests — nothing else.

## Writing Interface Contracts

The interface block defines class/function names, method signatures, parameter types, and return types. The small model must match these exactly so downstream tasks can import and use the component.

**Include:**
- Class/type name and inheritance
- All public method signatures with type annotations
- Property definitions if used
- Class-level constants or attributes

**Do not include:**
- Method bodies
- Private/internal methods
- Standard library imports
- Module-level instantiation of environment-dependent objects (e.g. `settings = Settings()`, `client = DbClient()`). These objects read from environment variables, files, or network at construction time — none of which exist in a test environment. Every file that imports the module triggers the constructor at import time, causing collection failures across all transitively-importing test files before a single test runs. Specify the class only; callers construct instances inside their own callables when they need them.

**Do include in Dependencies:**
- Import paths for project-internal modules the component uses
- Which task created each dependency

### Verify Abstract Type Fit Before Writing the Interface

When a task implements an abstract base type, verify that the base type's calling contract actually fits the component's data shape *before* writing the interface block. This is the single most common source of tasks that spiral: the model implements the specified method, the base calls it with the wrong type or cardinality, and the model exhausts all reflections reconciling a mismatch baked into the plan.

**The check:** For each abstract method the task must implement, ask: what does the base pass in, and what does this component actually need to receive?

- If the base calls `_process(item)` once per item and the component processes one item at a time → **fits. Specify the method as written.**
- If the base calls `_process(item)` once per item but the component needs to aggregate multiple items (e.g., grouping child rows under a parent) → **does not fit. The component must override the orchestrating method** (whatever the base uses to drive the abstract calls), not just implement `_process`.
- If the base contract is unclear from the plan alone → **read the base type source before specifying the interface.**

When the base does not fit, specify the override explicitly in the interface contract and call it out in the Behavior section:

```
// Override: this component overrides run() directly — base template does not fit
// _process() is NOT used
override run(context: Context): Result {
  // groups multiple sub-items into one output record
}
```

This pattern applies to any abstract type in any language. If the base drives abstract calls with a granularity that doesn't match the component, the task must specify the correct override level.

## Writing Behavior Specs

Behavior specs tell the model *what* to test without prescribing *how* to test it.

**Good behavior specs:**
```
- Filters records where timestamp > watermark
- Returns all records when watermark is 0
- Returns empty list when no records are newer than watermark
- maxTimestamp() returns the highest timestamp across records
- maxTimestamp() returns 0 for an empty list
```

**Bad (too vague):**
```
- Works correctly
- Handles edge cases
```

**Bad (prescribing implementation):**
```
- Create in-memory DB with columns (value INT, ts INT)
- Insert rows (10, 1000), (20, 2000)
- Assert len == 2
```

The sweet spot: describe *what the code does* precisely enough that any correct implementation would pass the tests, without dictating the test code itself.

## Writing Test Scenarios

Test scenarios are the input Claude Code uses to write actual test code during Step 3b. They are not instructions for the small model — the small model only sees the finished test file.

Write scenarios precise enough that Claude Code can derive correct assertions from them.

```
**Test scenarios:**
- watermark_filtering: 3 records at times 1000/2000/3000, filter with watermark=1500 → returns only records at 2000 and 3000
- watermark_zero: same data, watermark=0 → returns all 3
- no_new_records: same data, watermark=9999 → returns empty
- max_watermark: all records → maxTimestamp returns 3000
- max_watermark_empty: no records → maxTimestamp returns 0
```

**Key rules:**
- Name each scenario (Claude Code uses these as test function names)
- Specify concrete test data where it matters — exact values, not "some records"
- State the expected outcome unambiguously
- Cover boundary conditions explicitly
- Reference conftest fixtures by name when relevant
- Include at least one error/empty case per component

### Deployment Task Test Scenarios

Deployment tasks (Phase 7) have a different test shape from component and wiring tasks. There is no interface contract to verify — the model produces infrastructure files, not API surfaces. The test scenario is always a smoke test:

```
**Test scenarios:**
- [smoke_test]: Container builds successfully; service starts; health endpoint returns HTTP 200 within timeout
```

Claude Code writes a smoke test script (from a template) during Step 3b. Before writing the task doc, Claude Code also verifies the base image tag via `docker manifest inspect` and confirms the Dockerfile builds via `docker build` (see `agent-ready-plans` SKILL.md Step 3b and `stacks/infra.md` § "Base Image Verification"). The small model's job is to produce a Dockerfile and compose files that make the smoke test pass. The test compose must be self-contained — no external services required.

### Wiring Task Test Scenarios

Wiring tasks have a required test scenario that component tasks do not:

**`import_integrity`** — The pre-written test must explicitly import every class the wiring task will use, asserting each import succeeds. This test runs against the actual produced source files (not stubs), so it fails immediately if a small model drifted from a planned class name or module path.

```python
# Example — Python wiring task import integrity test
from plugins.extractors.steps_extractor import StepsExtractor
from plugins.extractors.blood_glucose_extractor import BloodGlucoseExtractor
# ... one line per component

def test_all_extractor_classes_importable():
    assert StepsExtractor is not None
    assert BloodGlucoseExtractor is not None
    # ... one assertion per class
```

The test doc for every wiring task must include this scenario and the instruction: *"Do not import any class not listed here. Do not infer additional classes from file names or directory structure."*

This is what makes wiring tasks safe to generate upfront alongside component tasks: the import integrity test catches any model drift at the wiring gate rather than letting a hallucinated import pass silently.

## Environment and Mocking Constraints

State constraints the model must satisfy, not implementation instructions.

**Good:**
```
**Testing constraints:**
- FrameworkX is NOT installed in the dev environment
- Test setup provides a stub that patches FrameworkX imports before collection
- Your implementation can import from FrameworkX at module level — the test setup handles it
- No real connections to external services in tests

**Available test fixtures** (use these instead of writing your own mocks):
- `mock_storage_client` — pre-wired cloud storage mock with upload capture
- `mock_queue_client` — pre-wired message broker mock with channel/publish
```

**Bad (prescribing mock implementation):**
```
Use this exact mock pattern:
  mockStorageClient.upload.mockResolvedValue({ key: 'test' })
```

## Phasing Guidelines

The phase structure mirrors how an engineering team handles dependencies: build components in isolation first, wire them together, package them for deployment, then run integration tests against live services.

```
Phase 1: Project Scaffolding     (Claude Code creates directly — not a task)
Phase 2: Core Abstractions       (base types, shared models, config)
Phase 3: Infrastructure Clients  (external service wrappers)
Phase 4: Primary Components      (main business logic — create files only, no wiring)
Phase 5: Secondary Components    (additional component implementations)
Phase 6: Wiring                  (dedicated tasks — generated upfront, sequenced after components)
Phase 7: Deployment              (Docker, compose files — sequenced after wiring, tested via smoke test)
Phase 8: Integration Tests       (service-gated — generated upfront, hard-fail if services unavailable)
```

**Phase 1 is special:** The project scaffold is created directly by Claude Code — not delegated to a small model.

**Component phases (2–5) create files only.** Each task produces its own source file and test file. No task in these phases touches a shared orchestrating file (DAG, router, registry, dispatcher). A component is independently testable in complete isolation — its `test_command` runs only its own test file.

**Phase 6 — Wiring — is generated upfront alongside component tasks.** Because interface contracts define exact class names and import paths, and because each wiring task's pre-written test includes an `import_integrity` scenario that validates those exact imports against produced files, wiring tasks do not need to be deferred. They are sequenced after their component dependencies in the runner — but the task docs and tests are written before the run starts. If a small model drifted on a name, the import integrity test fails at the wiring step, scoping the failure precisely instead of cascading silently.

A wiring task:
- Only has `Modify:` entries — it creates no new source files
- Has a pre-written test that includes `import_integrity` for every class it wires
- Includes the instruction: *"Do not import any class not listed here"*
- Runs the orchestrator test as its `test_command`
- Is sequenced after all component tasks it depends on

**Phase 7 — Deployment — packages the service into a container and validates it runs.** Each deployment task creates two compose files: a production compose (connecting to the shared platform network, assuming dependencies are pre-running) and a self-contained test compose (bundling all dependencies as local services so the smoke test needs only Docker installed). Claude Code writes the smoke test script; the small model writes the Dockerfile and compose files. Deployment tasks are always sequenced after the wiring task they depend on — this ensures the container packages known-good code.

The plan specifies the base image family and requirements (e.g. "Apache Airflow with Python 3.11") — not the exact tag. Claude Code resolves and verifies the actual tag during task-doc authoring via `docker manifest inspect`, then builds the Dockerfile against stubs to confirm it works before writing the spec into the task doc. This prevents the small model from receiving a broken Dockerfile it cannot fix.

A deployment task:
- Creates `Dockerfile`, `service.compose.yml`, and `service.test.compose.yml`
- Has no `Interface:` block — infrastructure files have no API surface to specify
- Has a `[smoke_test]` scenario: container starts, health endpoint returns 200
- Uses a per-task `lint_cmd` (hadolint + compose config) rather than the global language linter
- Uses a Docker smoke test script as `test_command` rather than a unit test runner
- The Dockerfile spec in the task doc has been verified to build by Claude Code — if the smoke test fails during the run, the failure is in the model's implementation, not the spec

**Phase 8 — Integration Tests — is service-gated, not deferred.** Integration test task docs are written upfront alongside all other tasks, because what they must test (end-to-end data flow, deduplication behavior, service interactions) is fully knowable from the design doc and interface contracts — no runtime discovery is needed. They are **not** deferred. The distinction is in how the runner handles them at execution time: the runner checks whether required services (e.g. MinIO, RabbitMQ, a database) are reachable before executing the task. If services are unavailable, the run **fails with an error** — it does not skip. This ensures every run produces a complete, verified result. Start required services before running the task suite, or resume with `--start N` after starting them.

In the manifest, integration test tasks use `"requires_services"` and `"service_check_commands"` — **not** `"deferred": true`. Do not mark integration tests as deferred in either the plan or the manifest.

This structure means a broken wiring task cannot cascade-fail component tasks — components were already verified in isolation. And a broken component is caught at the wiring task's import integrity test, not silently passing through the orchestrator.

## Deferred Tasks vs Service-Gated Tasks

These are two distinct categories. Confusing them produces incorrect runner behavior.

**Deferred** (`"deferred": true` in the manifest): The task doc genuinely cannot be written before the run starts, because its content depends on runtime artifacts produced by earlier tasks — actual class names, actual module paths, actual function signatures that only exist after the small model has implemented them. The runner halts when it reaches a deferred task and waits for Claude Code to generate the doc from the real produced code.

In practice, **no task category in a well-specified plan should be deferred** once wiring tasks are generated upfront with `import_integrity` tests. Deferred tasks are a fallback for plans where interface contracts are too loosely specified to enumerate exact import paths ahead of time.

**Service-gated** (`"requires_services": [...]` in the manifest, `"deferred": false`): The task doc exists and is complete upfront, but the task's execution requires live external services. The runner checks service health before executing and **exits with an error** if services are unavailable — it does not skip. This is the correct classification for **all integration tests**.

| Condition | Classification |
|---|---|
| Task doc content depends on runtime artifacts from earlier tasks | `deferred: true` |
| Task doc is complete upfront; execution needs live services | `requires_services: [...]`, `deferred: false` |
| Task runs fully with mocks | Standard task — neither |

**Never mark integration tests as deferred.** Their content (what services to call, what data to seed, what outcomes to assert) is fully derivable from the design doc and interface contracts before any code is written. Marking them deferred causes the runner to halt unnecessarily and requires a manual generation step that adds no value.

## Sizing Guidance

- **Simple tasks** (scaffolding, config): 1 task per file group
- **Moderate tasks** (one class + its tests): 1 task per component
- **Complex tasks** (multiple interacting files): split by responsibility, keeping tests with the component they test

If a task has more than 2 files in its "Create" list, consider splitting it. Wiring tasks are an exception — they may modify several files but create none. Deployment tasks are also an exception — they always create exactly three files (Dockerfile, production compose, test compose).
