# Test Writing & Validation Guide

The planning model authors tests during scaffold validation. Tests must be correct — both logically sound and mechanically robust. Incorrect tests are worse than no tests: the implementing model passes them trivially or gets stuck in a failing loop it can't escape.

---

## Task Scope: Component Tasks vs Wiring Tasks

Getting this wrong causes cascade failures that block entire phases.

**Component tasks create files only.** A component task produces one source file. Its test file already exists on disk (written during scaffold validation). The component is independently testable in isolation — its `test_command` runs only its own test file.

**Wiring tasks modify shared files only.** A wiring task registers components into an orchestrating file. It runs only after all component tasks it depends on are complete. Its test includes an `import_integrity` scenario that validates every class import against actual produced files.

**Why this matters:** If a component task also modifies a shared orchestrating file, every subsequent component's test gate fails — not because the component is wrong, but because the orchestrator was degraded by an earlier task. Keeping wiring separate prevents this cascade.

**In practice:**
- Task doc has `Files: Create:` only → correct component task
- Task doc has `Files: Modify:` alongside `Files: Create:` → split it
- Task doc has `Files: Modify:` only → correct wiring task

---

## Three-Layer Validation Gate

Every test file must pass all three layers before being marked `"pre_validated": true` in the manifest.

**Layer 0: Lint gate.** Run the project linter against the test file *before* running any tests. Fix all violations. A test file with lint errors traps the implementing model — it exhausts reflections trying to fix lint in a file it shouldn't edit. This is especially important for string literals: inline SQL, long argument lists, and schema definitions frequently exceed line-length limits. The linter must return zero errors before proceeding to Layer 1. See the relevant `stacks/<language>.md` file for the specific linter command.

**Layer 1: Mutation gate.** Run a mutation testing tool against the stub + tests. Strengthen tests until mutation score ≥ 80%. See `tooling.md` § "Mutation Testing".

**Layer 2: Correct failure mode.** Run `scripts/validate-stubs.sh <service-root>` — do NOT run pytest manually with piped/truncated output. Do NOT pipe the script itself through `| tail` or `| head`. The script writes all output to a timestamped log file automatically — read the log file for full tracebacks when investigating failures. The script runs each test file individually (including integration tests), sets `COLUMNS=300` to prevent pytest truncation, and programmatically verifies that every failure is `NotImplementedError` or `AssertionError`. It rejects:
- ❌ `TypeError` (e.g., `Can't instantiate abstract class` — stub missing an abstract method implementation)
- ❌ `FileNotFoundError` (e.g., constructor tries to load credentials from a nonexistent file)
- ❌ `ImportError` / `ModuleNotFoundError` (missing mock registration or import path)
- ❌ Any `ERROR at setup` (fixture wiring bug)
- ❌ Any test passing against the stub (test is vacuous)

The script must exit 0 before proceeding. If it reports invalid failures, read the log file for full tracebacks, fix the stub or test, and re-run. Do NOT work around failures by changing test structure (e.g., converting `pytest.exit()` to `skipif`).

All three layers must pass before marking `"pre_validated": true`.

---

## Wiring Task Tests

Wiring task tests run against actual produced source files, not stubs.

**Layer 0 (lint): same as component tasks.**

**Layer 1 (mutation gate): skip.** Wiring logic isn't algorithmic enough for meaningful mutation testing.

**Layer 2 (import integrity check): required.** Run the import integrity test against actual produced files. If any import fails, a component task drifted — fix it first.

**The `import_integrity` scenario is mandatory for every wiring task.** It explicitly imports every class the wiring task uses and asserts each is not None. This catches model drift at the wiring step rather than letting hallucinated imports pass silently. See the relevant `stacks/<language>.md` file for the language-specific import integrity test pattern.

Every wiring task doc must include: *"Do not import any class not listed here. Do not infer additional classes from file names or directory structure."*

**Mock constructor attribute checkpoint.** If the wiring task constructs an object from a framework class that is mocked (because the framework is not installed in the dev environment), and any test asserts on attributes of that object, the task doc's Behavior section must include explicit attribute assignments after the constructor call. Mock constructors may silently discard kwargs — the implementing model cannot diagnose this within its reflection budget. See the relevant `stacks/<language>.md` for the mock-specific trap pattern and fix.

---

## Anti-Patterns to Avoid

**Mocking the code under test.** Only mock external dependencies, never the class being tested.

**Asserting call counts instead of outputs.** Verify what the function returns or what state it produces.

**Skipping boundary conditions.** Test the boundary value explicitly, not just values clearly on one side.

**Happy-path-only tests.** Every behavior bullet needs a test, including error cases and empty inputs.

**Vacuous tests after fixing import errors.** If a test passes against the stub, it's testing nothing.

**Test functions must never contain `raise NotImplementedError`.** Only stubs raise `NotImplementedError` — tests are complete artifacts. Every test function must call the method under test and assert on the result. If the planning model cannot finish writing a test (due to context limits, usage limits, or complexity), it must stop and tell the user rather than leaving a stub test behind. The `validate-stubs.sh` script detects incomplete test functions via AST analysis and rejects them.

---

## Writing Tests That Exercise Contracts

- One test per behavioral requirement from the plan's Behavior section
- Use scaffold fixtures — don't re-mock what's already wired
- Data transformation: assert exact output structure, not just type
- Exclusion logic: test both sides (excluded absent, non-excluded present)
- Error handling: assert specific exception type and message
- Stateful operations: assert the state change, not just absence of errors
- Format-sensitive return values: when a method's return format matters to downstream consumers (e.g., UUID hex vs dashed string, date format, key format), include a direct test that asserts the exact format, not just a test that uses the value indirectly through a higher-level method. If the format mismatch only surfaces through an integration path, the implementing model gets a confusing failure it can't diagnose within its reflection budget.

---

## Stub Design

Stubs must be designed so mutation testing is meaningful:
- Methods raise "not implemented" or return null — not real values
- Class/type structure matches the interface contract exactly
- All imports resolve correctly
- No real logic

**Module-level singletons must not be instantiated in stubs.** A singleton constructor that requires runtime environment (env vars, files, network) causes collection failures across all transitively-importing test files. Replace with null/None; real instantiation belongs in the implementation task.

**Stubs must not execute code that requires runtime environment.** No environment variable reads, no file system access, no network connections at import time. Stubs define the class structure; they don't initialize operational state.

See `stacks/<language>-<framework>.md` for language-specific stub patterns.

---

## Schema Validation Rule

**Include validated schemas when tests check parsing.** If a test validates schema structure (e.g., Avro `parse_schema`, JSON Schema validation, protobuf descriptor checks), construct the exact schema during scaffold validation, validate it against the parsing library, and include it verbatim in the task doc's Behavior section. Implementing models cannot reliably construct schemas that satisfy library-specific constraints (named type deduplication, required field ordering, type reference rules). Without a pre-validated schema, the model invents one that may parse incorrectly, exhausts reflections on library-specific errors it cannot diagnose, and degrades. See the relevant `stacks/<language>.md` for library-specific schema traps.
