# Writing Task Docs for Small Models

Small models (7B-32B parameters) need a very different instruction style than Claude. They can follow precise instructions well, but struggle with ambiguity, inference, and connecting dots across context.

## Core Principles

**Be explicit, not clever.** Spell out every interface contract precisely. Instead of "follow the same pattern as the steps extractor", specify the exact class name, method signatures, and behavioral requirements.

**Interface contracts, not implementation code.** Define class names, method signatures with type hints, and behavioral specs. Do not include method bodies — the small model writes the implementation to pass the pre-written tests.

**Tests are Claude Code's responsibility.** Claude Code writes complete, verified test code during scaffold (Step 3b). Task docs embed the test file verbatim in the `## Tests` section. The small model's job is to implement the code to pass them — not to write tests.

**Environment constraints over mock instructions.** State what's mocked and what can't make real connections. Tests already handle the mock wiring — don't describe mock patterns in the task doc.

**Minimize context requirements.** The model shouldn't need to read other files to understand what to do. Include the interface of dependencies in the task doc (class name, key method signatures) along with the import path.

**Keep task docs under 2000 tokens.** Small model context windows are limited. Spec-based tasks are naturally shorter than code-based tasks, so this limit is easier to hit.

**Always include the output constraint.** Small models often append conversational text like "To test this, run..." or "If you want to run the tests...". Aider's `whole` edit format interprets these as filenames and creates junk files at the project root. Every task's Project Context section must end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.`

## Writing Correct Tests

Claude Code authors tests during Step 3b. The tests must be correct — both logically sound and mechanically robust. Incorrect tests are worse than no tests: the small model passes them trivially while the real behavior goes unvalidated, or gets stuck in a failing loop it can't escape.

### Two-Layer Validation Gate

Every test file must pass both layers before being embedded in a task doc:

**Layer 1: Mutation gate.** Run a mutation testing tool against the stub implementation + tests. A surviving mutant means a test that would pass even if that logic were changed — a weak assertion. Strengthen tests until mutation score ≥ 80%. See `tooling.md` § "Mutation Testing" for tool selection by language.

**Layer 2: Correct failure mode.** Run the test suite against the stub. Every test must fail, and must fail for the right reason:
- ✅ `NotImplementedError` — stub body raises it correctly
- ✅ Assertion failure on a wrong return value — stub returns `None` where a real value is expected
- ❌ `ImportError` or `ModuleNotFoundError` — test infrastructure is broken, fix it
- ❌ `TypeError` in test setup code — the test itself has a bug, fix it
- ❌ `AttributeError` on a fixture — conftest fixture is mis-wired, fix it
- ❌ Any test passes against the stub — the test is vacuous, strengthen it

### Anti-Patterns to Avoid

These produce tests that pass trivially or test the wrong thing:

**Mocking the code under test.** Never patch the class or function being tested. Only patch its external dependencies.
```python
# WRONG — patches the code under test, test always passes
with patch("mymodule.MyClass.filter") as mock:
    mock.return_value = expected
    result = MyClass().filter(input)  # calls mock, not implementation
    assert result == expected  # trivially true

# CORRECT — only patches the external DB dependency
with patch("mymodule.db_client") as mock_db:
    mock_db.query.return_value = raw_rows
    result = MyClass().filter(input)  # calls real implementation
    assert result == filtered_rows  # tests actual logic
```

**Asserting call counts instead of outputs.** Verify what the function returns or what state it produces, not how many times it called a mock.
```python
# WEAK — passes even if the function returns garbage
assert mock_db.query.call_count == 1

# STRONG — verifies the actual output value
assert result == [row for row in rows if row.ts > watermark]
```

**Skipping boundary conditions.** For any filtering, sorting, or conditional logic, always test the boundary explicitly.
```python
# INSUFFICIENT — only tests values clearly on one side
def test_filter():
    rows = [Row(ts=500), Row(ts=2000)]
    assert filter(rows, watermark=1000) == [Row(ts=2000)]

# COMPLETE — tests the boundary value itself
def test_filter_boundary():
    rows = [Row(ts=999), Row(ts=1000), Row(ts=1001)]
    result = filter(rows, watermark=1000)
    assert result == [Row(ts=1001)]  # 1000 is excluded, 1001 is included
```

**Happy-path-only tests.** Every behavior bullet in the task doc must have a corresponding test, including error cases and empty inputs.

**Vacuous tests after fixing import errors.** If a test passes against the stub after you fix an import error, the test is testing nothing — it will also pass against a broken implementation. Make it assert something real.

### Writing Tests That Exercise Contracts

- Write one test per behavioral requirement from the `## Behavior` section
- Use the conftest fixtures from the scaffold — don't re-mock what's already wired
- For data transformation: assert on the exact output structure, not just its type
- For exclusion logic: test both sides (excluded item absent, non-excluded item present)
- For error handling: assert the specific exception type and message where specified
- For stateful operations: assert the state change, not just the absence of errors

### Stub Design

Stubs must be designed so mutation testing is meaningful:
- Methods return `None` or raise `NotImplementedError` — not real values
- Class structure matches the interface contract exactly (correct names, signatures, type hints)
- All imports resolve correctly (no import errors at collection time)
- Do not include any real logic — if a stub accidentally implements part of the logic, mutants in that path may be killed by the stub itself, not by the tests

**Module-level singletons must not be instantiated in stubs.** If a module defines a singleton (e.g., `settings = Settings()`), and other stubs import that module at the top level, the singleton constructor runs at collection time. If the constructor requires runtime environment (env vars, files, network), pytest collection fails with an error — not a test failure — and the Layer 2 check cannot be completed for any test file that transitively imports it.

Stub rule: replace any module-level singleton instantiation with `None`:
```python
# WRONG — Settings() requires env vars; fails at collection if env vars absent
settings = Settings()

# CORRECT stub — importable without env vars; implementation task sets the real value
settings = None
```

The real `settings = Settings()` belongs only in the final implementation (Task 2.1 in this case), not in the stub. Once Task 2.1 is implemented, the DAG and other modules that import `settings` will get the real value — which is correct, because by that point the implementation tasks have run in order.

Example Python stub:
```python
class RecordFilter:
    def filter(self, rows: list[Row], watermark: int) -> list[Row]:
        raise NotImplementedError

    def count(self, rows: list[Row]) -> int:
        raise NotImplementedError
```

After mutation gate and failure mode validation pass, remove the method bodies (leave `raise NotImplementedError`) and embed the test file in the task doc.

## Deferred Tasks

Some tasks cannot be accurately written before the implementation tasks run, because they depend on the exact interfaces, signatures, or structures that earlier tasks produce. Small models may deviate from the plan — slightly different parameter names, return types, class hierarchies — and a task doc written against the planned interface will fail against the actual one.

**Mark a task as deferred when it:**
- Tests functions or classes created by multiple earlier tasks (integration tests, end-to-end tests)
- Wires together components whose exact APIs are defined by other tasks (DAG assembly that imports from many modules, router/dispatcher that calls multiple handlers)
- Modifies files created by earlier tasks in ways that depend on their exact content (adding registrations, updating import maps)

**No need to defer tasks that:**
- Only test code within the same task doc (unit tests) — these are self-contained by design
- Create standalone components with no cross-task interface dependencies
- Follow a well-defined base class pattern where the interface is fixed (e.g., all extractors implement the same ABC — the contract is known upfront)

**How deferred tasks work:**

1. During initial generation (Step 5), create a manifest entry with `"deferred": true`, `"deferred_reason"`, and `"depends_on"` listing the task IDs it depends on. Skip creating the `.md` task doc file — it will be generated later from real code.
2. The runner skips deferred tasks and stops after the last non-deferred task completes.
3. The user invokes Claude Code to generate the deferred task docs. Claude Code reads the actual implementation files (not the plan) and writes task docs with real function signatures, real parameter names, and real import paths.
4. The user resumes the runner with `--start N` to execute the deferred tasks through aider as normal.

**Example manifest entry for a deferred task:**
```json
{
  "file": "25-task-12.1-dag-integration-test.md",
  "task_id": "12.1",
  "title": "DAG Integration Tests",
  "phase": "Integration Testing",
  "files_created": ["services/airflow-ingestion/tests/test_dag_integration.py"],
  "estimated_complexity": "complex",
  "deferred": true,
  "deferred_reason": "Tests real function signatures from task_functions.py, watermark_manager.py, and all extractors. Must use actual interfaces, not planned ones.",
  "depends_on": ["8.1", "9.1", "10.1", "11.1"]
}
```

When generating a deferred task doc after implementation, follow the same task-template.md structure but read the actual source files for imports, signatures, and parameter names. Do not reference the original plan for interface details — the implementation is the source of truth.

## Task Splitting Guidelines

Spec-based task docs are naturally shorter than code-based ones, so splitting is less common. If a task doc still exceeds ~2000 tokens (usually because the interface has many methods or the test scenarios are extensive):

1. Split by responsibility — e.g., "create config" and "create the component + tests" as separate tasks
2. Keep "create file" and "modify file" as separate tasks
3. **Never split the implementation from its pre-written tests.** The task doc embeds the test file Claude Code authored — the implementation task must include those tests so the small model has a concrete pass/fail criterion.

**Example split:**
```
Original: Task 5.1 — Airflow DAG (complex, many extractors to register)
Split into:
  - 14-task-5.1a-dag-config-and-test-infra.md  (conftest updates, test utilities)
  - 15-task-5.1b-dag-implementation.md          (DAG code + DAG import tests)
```

Update the manifest to reflect the split and keep sequential numbering intact.

## Complexity Ratings

Used in the manifest and task headers to set expectations:

| Rating | Description | Example |
|--------|-------------|---------|
| **simple** | Create files, no logic, boilerplate | Directory scaffolding, requirements.txt, Dockerfile |
| **moderate** | One class/module with clear logic, has tests | A record extractor, a parser, a client wrapper |
| **complex** | Multiple interacting components, joins, edge cases | DAG assembly, consumer routing with format detection |

## Adapting for Different Agents

The task docs are agent-agnostic markdown. While the runner defaults to aider + LMStudio, the same files work with:

- **Claude Code** — `cat task-file.md | claude-code` or paste into a session
- **Codex CLI** — use as input prompt
- **Any agent with a message-file param** — the format is universal

To add a new agent backend, change the command and arguments in the runner script.
