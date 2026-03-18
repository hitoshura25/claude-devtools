# Writing Task Docs for Small Models

Small models (7B-32B parameters) follow precise instructions well but struggle with ambiguity, inference, and connecting dots across context.

## Core Principles

**Be explicit, not clever.** Spell out every interface contract precisely. Instead of "follow the same pattern as the previous component", specify the exact class/function name, method signatures, and behavioral requirements.

**Show the base class call site for abstract methods.** The model only sees the abstract signature — not how the base class calls it. For every abstract method the task implements, include one line showing the concrete call:

```
# From base.process() — called once per item returned by _query():
result = self._transform(item)  # item is a single Row, not a list
```

This applies to any abstract/interface pattern: parsers, handlers, strategies, validators. One line prevents the model from assuming the wrong type, cardinality, or calling convention.

**Wiring task Behavior sections must use code snippets for all callable bodies — no prose.** Unconditional, no length judgement needed. Prose descriptions produce one-liner transcriptions that exceed line-length limits, triggering lint spirals that consume the model's reflection budget. Show the code; let the model copy it.

```python
# WRONG — prose leads to one-liner transcription:
# "pulls the zip path from XCom and unzips it to a temp directory"

# CORRECT — show the exact code:
zip_path = context["task_instance"].xcom_pull(
    key="zip_path",
    task_ids="download_zip",
)
```

This rule applies only to **wiring task Behavior sections**. Component tasks use interface contracts and behavioral specs — the model writes the implementation to pass the pre-written tests.

**Interface contracts, not implementation code.** For component tasks: define class/function names, signatures with type annotations, and behavioral specs. No method bodies.

**Tests are on disk, not in the task doc.** Claude Code writes and validates test files during Step 3b and saves them to disk. Task docs reference the test file by path — they do not embed a copy. This eliminates the divergence risk where a validated on-disk test and the embedded copy in the task doc differ due to LLM non-determinism at generation time (see T23, T24, T27 pattern).

**Environment constraints over mock instructions.** State what's mocked and what can't make real connections. Tests already handle mock wiring.

**Minimize context requirements.** Include the interface of dependencies in the task doc (class name, key method signatures, import path) so the model doesn't need to read other files.

**Keep task docs under 2000 tokens.** Small model context windows are limited. Removing embedded test code helps significantly here.

**Always include the output constraint.** Small models often append conversational text after code. Every task's Project Context section must end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.`

---

## Task Scope: Component Tasks vs Wiring Tasks

Getting this wrong causes cascade failures that block entire phases.

**Component tasks create files only.** A component task produces one source file. Its test file already exists on disk (written by Claude Code in Step 3b). The component is independently testable in isolation — its `test_command` runs only its own test file.

**Wiring tasks modify shared files only.** A wiring task registers components into an orchestrating file. It runs only after all component tasks it depends on are complete. Its test includes an `import_integrity` scenario that validates every class import against actual produced files.

**Why this matters:** If a component task also modifies a shared orchestrating file, every subsequent component's test gate fails — not because the component is wrong, but because the orchestrator was degraded by an earlier task. Keeping wiring separate prevents this cascade.

**In practice:**
- Task doc has `Files: Create:` only → correct component task
- Task doc has `Files: Modify:` alongside `Files: Create:` → split it
- Task doc has `Files: Modify:` only → correct wiring task

---

## Writing Correct Tests

Claude Code authors tests during Step 3b. Tests must be correct — both logically sound and mechanically robust. Incorrect tests are worse than no tests: the model passes them trivially or gets stuck in a failing loop it can't escape.

### Three-Layer Validation Gate

Every test file must pass all three layers before being marked `"pre_validated": true` in the manifest.

**Layer 0: Lint gate.** Run the project linter against the test file *before* running any tests. Fix all violations. A test file with lint errors traps the small model — it exhausts reflections trying to fix lint in a file it shouldn't edit. This is especially important for string literals: inline SQL, long argument lists, and schema definitions frequently exceed line-length limits.

```bash
# Python/ruff example:
ruff check services/my-service/tests/test_my_component.py
# Must return zero errors before proceeding to Layer 1
```

**Layer 1: Mutation gate.** Run a mutation testing tool against the stub + tests. Strengthen tests until mutation score ≥ 80%. See `tooling.md` § "Mutation Testing".

**Layer 2: Correct failure mode.** Run tests against the stub. Every test must fail for the right reason:
- ✅ "not implemented" error or assertion failure on wrong return value
- ❌ Import/module error, type error in setup, fixture error, or any test passing against the stub

All three layers must pass before marking `"pre_validated": true`.

### Wiring Task Tests

Wiring task tests run against actual produced source files, not stubs.

**Layer 0 (lint): same as component tasks.**

**Layer 1 (mutation gate): skip.** Wiring logic isn't algorithmic enough for meaningful mutation testing.

**Layer 2 (import integrity check): required.** Run the import integrity test against actual produced files:

```bash
cd services/my-service && uv run pytest tests/test_orchestrator.py::test_all_classes_importable -x -q
```

If any import fails, a component task drifted — fix it first.

**The `import_integrity` scenario is mandatory for every wiring task.** It explicitly imports every class the wiring task uses and asserts each is not None. This catches model drift at the wiring step rather than letting hallucinated imports pass silently.

```python
from plugins.extractors.steps_extractor import StepsExtractor
from plugins.extractors.blood_glucose_extractor import BloodGlucoseExtractor
# ... one line per component

def test_all_extractor_classes_importable():
    assert StepsExtractor is not None
    assert BloodGlucoseExtractor is not None
```

Every wiring task doc must include: *"Do not import any class not listed here. Do not infer additional classes from file names or directory structure."*

**Wiring Behavior sections use code snippets unconditionally.** See Core Principles above for the rationale.

### Anti-Patterns to Avoid

**Mocking the code under test.** Only mock external dependencies, never the class being tested.

**Asserting call counts instead of outputs.** Verify what the function returns or what state it produces.

**Skipping boundary conditions.** Test the boundary value explicitly, not just values clearly on one side.

**Happy-path-only tests.** Every behavior bullet needs a test, including error cases and empty inputs.

**Vacuous tests after fixing import errors.** If a test passes against the stub, it's testing nothing.

### Writing Tests That Exercise Contracts

- One test per behavioral requirement from `## Behavior`
- Use scaffold fixtures — don't re-mock what's already wired
- Data transformation: assert exact output structure, not just type
- Exclusion logic: test both sides (excluded absent, non-excluded present)
- Error handling: assert specific exception type and message
- Stateful operations: assert the state change, not just absence of errors

### Stub Design

Stubs must be designed so mutation testing is meaningful:
- Methods raise "not implemented" or return null — not real values
- Class/type structure matches the interface contract exactly
- All imports resolve correctly
- No real logic

**Module-level singletons must not be instantiated in stubs.** A singleton constructor that requires runtime environment (env vars, files, network) causes collection failures across all transitively-importing test files. Replace with null/None; real instantiation belongs in the implementation task.

See `stacks/<language>-<framework>.md` for language-specific stub patterns.

---

## Deferred Tasks vs Service-Gated Tasks

Two distinct categories. Conflating them causes unnecessary runner pauses.

### Deferred Tasks — task doc cannot be written upfront

A task is **deferred** only when its content depends on runtime artifacts that don't yet exist (actual class names, module paths, function signatures from earlier tasks).

Wiring tasks are now generated upfront with `deferred: false` because interface contracts define exact class names and `import_integrity` catches drift. A wiring task may still be deferred if interface contracts are loosely specified.

### Service-Gated Tasks — execution needs live services

Integration tests are **not deferred** — they can be fully written before the run. Mark with `"requires_services"` in the manifest. The runner checks service health and **exits with an error** if services are unavailable — it does not skip.

**Rule for deciding:**

| Condition | Classification |
|-----------|---------------|
| Task doc depends on runtime artifacts from earlier tasks | `deferred: true` |
| Task doc is complete upfront; execution needs live services | `requires_services: [...]`, `deferred: false` |
| Task runs in isolation with mocks | Standard task |

---

## Task Splitting Guidelines

If a task doc exceeds ~2000 tokens, split by responsibility (e.g., "create config" and "create the component" as separate tasks). **Never split the implementation from its test file** — the model needs both to do its job.

---

## Complexity Ratings

| Rating | Description | Example |
|--------|-------------|---------|
| **simple** | Create files, no logic, boilerplate | Config files, Dockerfile |
| **moderate** | One class/module with clear logic | A client wrapper, a parser |
| **complex** | Multiple interacting components, edge cases | Orchestrator assembly, routing |

---

## Adapting for Different Agents

Task docs are agent-agnostic markdown. The same files work with aider + LMStudio, Claude Code, Codex CLI, or any agent with a message-file param. To add a new backend, change the runner script.
