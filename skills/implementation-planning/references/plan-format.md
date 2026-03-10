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

## Phase N: Integration Tests (deferred)

### Task N.1: [Integration Test Name] *(deferred)*

**Deferred:** Generate after implementation tasks complete — tests depend
on real function signatures and import paths from earlier tasks.

**What to test:**
- [Description of integration scenarios]
- [Components being integrated]

**Depends on:** Tasks X.Y, X.Z, ...
```

## Task Template

Each task defines an interface contract that the small model implements. The precision of the contract determines whether the model produces correct code.

**Tests and implementation belong in the same task.** Claude Code writes the test file during the scaffold phase and embeds it in the task doc. The small model implements against it. Never split the test file into a separate task from its implementation.

```markdown
### Task X.Y: [Component Name]

**Files:**
- Create: `exact/path/from/project/root/component.ext`
- Create: `tests/exact/path/test_component.ext`
- Modify: `exact/path/to/existing.ext` (add new entry to REGISTRY)

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

**Wiring:**
- Add import and append `ComponentName()` to `REGISTRY` in `path/to/registry.ext`
```

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

The first tells the model what constraints to satisfy. The second gives it code that might have a subtle bug.

## Phasing Guidelines

Group tasks into phases that build on each other.

```
Phase 1: Project Scaffolding (Claude Code creates directly — not a task)
Phase 2: Core Abstractions (base types, shared models, config)
Phase 3: Infrastructure Clients (external service wrappers)
Phase 4: Primary Components (main business logic)
Phase 5: Orchestration (scheduler, router, dispatcher)
Phase 6: Remaining Components (additional implementations of Phase 4 patterns)
Phase 7: Deployment (Docker, infra config)
Phase 8: Integration Tests (deferred)
```

**Phase 1 is special:** The project scaffold is created directly by Claude Code — not delegated to a small model. The plan lists what the scaffold contains so Claude Code knows what to create.

**The critical ordering rule:** Orchestration tasks (Phase 5) come *after* the components they initially register but *before* later phases that add more. Phase 6 tasks each include a wiring step to register themselves.

**When a later task must register itself in an earlier component,** include a "Modify" entry and a "Wiring" section:

```markdown
### Task 6.3: FooExtractor

**Files:**
- Create: `src/extractors/foo_extractor.ext`
- Create: `tests/extractors/test_foo_extractor.ext`
- Modify: `src/orchestrator.ext` (add FooExtractor to REGISTRY)

**Wiring:**
- Import FooExtractor in orchestrator
- Append FooExtractor() to REGISTRY list
```

This is the single most common source of decomposition bugs. See `wiring-completeness.md` for the full checklist.

## Deferred Tasks

Mark tasks as deferred when they depend on exact function signatures, class hierarchies, or import paths that earlier tasks produce. Include enough detail for Claude Code to generate them later:
- What components are being integrated
- What scenarios to test
- Which tasks they depend on

## Sizing Guidance

- **Simple tasks** (scaffolding, config): 1 task per file group
- **Moderate tasks** (one class + its tests): 1 task per component
- **Complex tasks** (multiple interacting files): split by responsibility, keeping tests with the component they test

If a task has more than 3 files in its "Create" list, consider splitting it.
