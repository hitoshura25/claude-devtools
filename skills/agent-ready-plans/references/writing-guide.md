# Writing Task Docs for Small Models

Small models (7B-32B parameters) need a very different instruction style than large models. They can follow precise instructions well, but struggle with ambiguity, inference, and connecting dots across context.

## Core Principles

**Be explicit, not clever.** Spell out every interface contract precisely. Instead of "follow the same pattern as the previous component", specify the exact class/function name, method signatures, and behavioral requirements.

**Show the base class call site for abstract methods.** When a task implements methods from an inherited abstract type, the model only sees the abstract signature — not how the base class actually calls it. Without the call site, the model guesses the argument type and cardinality, and guesses wrong. For every abstract method the task must implement, include one line showing the concrete call from the base:

```
# From base.process() — called once per item returned by _query():
result = self._transform(item)  # item is a single Row, not a list
```

This applies to any abstract/interface pattern across any language: parsers, handlers, strategies, validators. If the base orchestrates calls to the abstract method, show it. One line prevents the model from assuming the wrong type, wrong cardinality, or a different calling convention.

**Interface contracts, not implementation code.** Define class/function names, signatures with type annotations, and behavioral specs. Do not include bodies — the small model writes the implementation to pass the pre-written tests.

**Tests are Claude Code's responsibility.** Claude Code writes complete, verified test code during scaffold (Step 3b). Task docs embed the test file verbatim in the `## Tests` section. The small model's job is to implement the code to pass them — not to write tests.

**Environment constraints over mock instructions.** State what's mocked and what can't make real connections. Tests already handle the mock wiring — don't describe mock patterns in the task doc.

**Minimize context requirements.** The model shouldn't need to read other files to understand what to do. Include the interface of dependencies in the task doc (class name, key method signatures) along with the import path.

**Keep task docs under 2000 tokens.** Small model context windows are limited.

**Always include the output constraint.** Small models often append conversational text after their code. Some agent frameworks interpret this as filenames and create junk files. Every task's Project Context section must end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.`

---

## Writing Correct Tests

Claude Code authors tests during Step 3b. The tests must be correct — both logically sound and mechanically robust. Incorrect tests are worse than no tests: the small model passes them trivially while the real behavior goes unvalidated, or gets stuck in a failing loop it can't escape.

### Two-Layer Validation Gate

Every test file must pass both layers before being embedded in a task doc:

**Layer 1: Mutation gate.** Run a mutation testing tool against the stub + tests. A surviving mutant means a test that would pass even if that logic were changed — a weak assertion. Strengthen tests until mutation score ≥ 80%. See `tooling.md` § "Mutation Testing" for tool selection by language.

**Layer 2: Correct failure mode.** Run the test suite against the stub. Every test must fail, and must fail for the right reason:
- ✅ Stub raises "not implemented" error — stub body is correctly empty
- ✅ Assertion failure on a wrong return value — stub returns null/None where a real value is expected
- ❌ Import/module resolution error — test infrastructure is broken, fix it
- ❌ Type error in test setup code — the test itself has a bug, fix it
- ❌ Fixture/mock setup error — the test fixture is mis-wired, fix it
- ❌ Any test passes against the stub — the test is vacuous, strengthen it

### Anti-Patterns to Avoid

These produce tests that pass trivially or test the wrong thing:

**Mocking the code under test.** Never mock/stub the class or function being tested. Only mock its external dependencies.

```
// WRONG — mocks the code under test; test always passes
mockImplementation(MyClass.prototype.filter, () => expected)
result = new MyClass().filter(input)  // calls mock
assert(result === expected)           // trivially true

// CORRECT — only mocks the external DB dependency
mockImplementation(dbClient.query, () => rawRows)
result = new MyClass().filter(input)  // calls real implementation
assert(result === filteredRows)       // tests actual logic
```

**Asserting call counts instead of outputs.** Verify what the function returns or what state it produces, not how many times it called a mock.

**Skipping boundary conditions.** For any filtering, sorting, or conditional logic, test the boundary value explicitly — not just values clearly on one side.

**Happy-path-only tests.** Every behavior bullet in the task doc must have a corresponding test, including error cases and empty inputs.

**Vacuous tests after fixing import errors.** If a test passes against the stub after you fix an import error, the test is testing nothing. Make it assert something real.

### Writing Tests That Exercise Contracts

- Write one test per behavioral requirement from the `## Behavior` section
- Use the fixtures from the scaffold — don't re-mock what's already wired
- For data transformation: assert on the exact output structure, not just its type
- For exclusion logic: test both sides (excluded item absent, non-excluded item present)
- For error handling: assert the specific exception/error type and message where specified
- For stateful operations: assert the state change, not just the absence of errors

### Test Scope Rule

**A task's `test_command` covers only the test file for the component it creates.** Tests for files the task *modifies* (registries, routers, DAGs, orchestrators) belong in the global full-suite check — not in the per-task gate. Including a shared orchestrator's test file in a component task's test command means a broken orchestrator will cascade-fail all downstream component tasks, even when those components are individually correct.

### Stub Design

Stubs must be designed so mutation testing is meaningful:
- Methods raise "not implemented" or return null — not real values
- Class/type structure matches the interface contract exactly
- All imports resolve correctly (no import errors at collection time)
- Do not include any real logic

**Module-level singletons must not be instantiated in stubs.** If a module defines a singleton at the top level (e.g., `config = Config()`), and other stubs import that module, the singleton constructor runs at collection time. If the constructor requires runtime environment (env vars, files, network), test collection fails — not a test failure — and Layer 2 validation cannot complete for any file that transitively imports it.

Stub rule: replace any module-level singleton instantiation with a null/None equivalent. The real instantiation belongs only in the final implementation task.

See `stacks/<language>-<framework>.md` for language-specific stub patterns (e.g., `raise NotImplementedError` in Python, `throw new Error('not implemented')` in TypeScript).

---

## Deferred Tasks

Some tasks cannot be accurately written before the implementation tasks run, because they depend on the exact interfaces, signatures, or structures that earlier tasks produce. Small models may deviate from the plan — slightly different parameter names, return types, class hierarchies.

**Mark a task as deferred when it:**
- Tests functions or classes created by multiple earlier tasks (integration tests, end-to-end tests)
- Wires together components whose exact APIs are defined by other tasks (orchestrators, routers, dispatchers)
- Modifies files created by earlier tasks in ways that depend on their exact content

**No need to defer tasks that:**
- Only test code within the same task doc (unit tests)
- Create standalone components with no cross-task interface dependencies
- Follow a well-defined base type pattern where the interface is fixed upfront

**How deferred tasks work:**

1. During initial generation (Step 5), create a manifest entry with `"deferred": true`, `"deferred_reason"`, and `"depends_on"`. Skip creating the task doc file.
2. The runner skips deferred tasks and stops after the last non-deferred task.
3. Invoke Claude Code to generate the deferred task docs — read actual implementation files, not the plan.
4. Resume the runner with `--start N`.

**Example manifest entry:**
```json
{
  "file": "25-task-12.1-integration-test.md",
  "task_id": "12.1",
  "title": "Pipeline Integration Tests",
  "estimated_complexity": "complex",
  "deferred": true,
  "deferred_reason": "Tests real function signatures from all implementation tasks. Must use actual interfaces, not planned ones.",
  "depends_on": ["8.1", "9.1", "10.1", "11.1"]
}
```

When generating a deferred task doc, read the actual source files for imports, signatures, and parameter names. Do not reference the original plan — the implementation is the source of truth.

---

## Task Splitting Guidelines

If a task doc exceeds ~2000 tokens:

1. Split by responsibility — e.g., "create config" and "create the component + tests" as separate tasks
2. Keep "create file" and "modify file" as separate tasks
3. **Never split the implementation from its pre-written tests.** The task doc embeds the test file — the model needs both to do its job.

Update the manifest to reflect the split and keep sequential numbering intact.

---

## Complexity Ratings

| Rating | Description | Example |
|--------|-------------|---------|
| **simple** | Create files, no logic, boilerplate | Scaffolding, config files, Dockerfile |
| **moderate** | One class/module with clear logic, has tests | A client wrapper, a parser, a data transformer |
| **complex** | Multiple interacting components, joins, edge cases | Orchestrator assembly, routing with format detection |

---

## Adapting for Different Agents

The task docs are agent-agnostic markdown. While the runner defaults to aider + LMStudio, the same files work with:

- **Claude Code** — `cat task-file.md | claude-code` or paste into a session
- **Codex CLI** — use as input prompt
- **Any agent with a message-file param** — the format is universal

To add a new agent backend, change the command and arguments in the runner script.
