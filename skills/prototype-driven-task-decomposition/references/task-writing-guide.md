# Phase 2: Task Writing — Detailed Guidance

## The Self-Containment Rule

The most important principle: **each task must be understandable without the
design doc or other tasks.**

The implementing model (Qwen/Codestral via Aider) receives:
1. This task's JSON definition
2. Access to the prototype directory
3. Access to the growing project codebase
4. Lint and test commands to run

It does NOT receive:
- The full design doc
- Other task definitions
- The conversation history from planning
- The dependency graph

This means the task's `description` field must include enough context that the
model knows what to build and why. Not a copy of the design doc — just the
relevant subset.

### Good vs Bad Descriptions

**Bad** (assumes context from the design doc):
> "Create the health sync client as described in the Architecture section."

**Bad** (too vague for a local model):
> "Build the API client."

**Good** (self-contained, specific):
> "Create an HTTP client that fetches health records from the Apple HealthKit
> REST API. The client should accept an auth token and date range, call the
> /v1/records endpoint, and return a list of parsed HealthRecord objects.
> See prototypes/health-sync/fetch.py for the working request/response pattern.
> The API returns paginated JSON — the prototype handles the first page only,
> but production needs to follow pagination links until exhausted."

### Description Template

For consistency, structure descriptions as:

1. **What** — What this task creates or modifies (one sentence)
2. **Why** — Why this component exists in the architecture (one sentence)
3. **How** — Key technical details the implementing model needs (1-2 sentences)
4. **Prototype note** — What the prototype proved vs what production needs
   differently (one sentence, if applicable)

## Writing File Changes

Every task must specify at least one file in its `files` list. Be precise about
paths — the implementing model will create exactly these files.

### Path conventions

- Use project-relative paths: `src/health_sync/client.py`, not `/Users/me/project/src/...`
- Follow the existing project's directory conventions (discovered during planning)
- Include `__init__.py` files when creating new Python packages — don't assume
  they exist

### Create vs Modify

- `create` — The file doesn't exist yet. The implementing model writes it from scratch.
- `modify` — The file already exists (created by a prior task or part of the existing
  codebase). The implementing model edits it. When modifying, the `description`
  should say what to add or change, not describe the whole file.

### Common mistakes

- **Forgetting `__init__.py`**: If a task creates `src/health_sync/client.py` and
  `src/health_sync/` is a new package, include `src/health_sync/__init__.py` in
  the files list (usually in the scaffold task).
- **Forgetting config imports**: If the project uses a central config module and
  this task needs config values, include the config modification in the files list.
- **Overlapping file modifications**: Two tasks should never modify the same file.
  If they need to, either merge the tasks or make one depend on the other with
  clear instructions about what each modifies.

## Writing Prototype References

Prototype references tell the implementing model: "This file in the prototype
demonstrates a pattern you should follow." Be specific about what to take from it.

### Good references

```json
{
  "file": "fetch.py",
  "what_to_reference": "The request headers setup at lines 12-18 — the API requires a specific User-Agent and Accept header format"
}
```

```json
{
  "file": "tests/conftest.py",
  "what_to_reference": "The mock API response fixture — use this shape for test data, it matches the real API response format"
}
```

### Bad references

```json
{
  "file": "fetch.py",
  "what_to_reference": "The fetch logic"
}
```
This is too vague. The implementing model will read the whole file and might copy
too much or too little.

### When to skip references

Some tasks don't need prototype references:
- Scaffold tasks (creating directory structure, `__init__.py` files)
- Config-only tasks (environment variable setup, settings classes)
- Tasks where the existing codebase — not the prototype — is the reference

## TDD Task Pairs

Every component with testable logic produces a pair of tasks: a test task
followed by an implementation task. This is the core structural rule of the
decomposition — a task never writes both tests and production code.

### Why strict separation matters

The planning model (running this skill) understands the full architecture.
The implementing model (Qwen/Codestral ~30B) sees one task at a time. By
writing tests first:

1. The planning model's understanding of "correct behavior" is captured as
   executable tests — not as prose the implementing model might misinterpret.
2. The implementing model gets immediate, concrete feedback: either the tests
   pass or they don't. No ambiguity about whether the code is correct.
3. If the implementing model gets stuck, the failing test output tells it
   exactly what's wrong — a much tighter feedback loop than vague acceptance
   criteria.

### Test task structure

A test task (`task_type: "test"`) writes test files only.

**Files**: Only test files (e.g., `tests/test_extractor.py`, `tests/conftest.py`).
Never production code.

**Tests field**: Lists the test cases to write. Each `TestCriterion` describes
one test the model should create.

**Acceptance criteria**:
- "Test file is syntactically valid and importable"
- "Tests fail because the implementation module does not exist yet" (or
  "tests fail because the stub raises NotImplementedError" if a stub exists)
- "Lint passes with zero errors"

**Prototype references**: Point to prototype test files for fixture patterns,
conftest structure, and test organization.

**Security considerations**: Usually empty — security concerns go on the
implementation task.

### Implementation task structure

An implementation task (`task_type: "implementation"`) writes production code
only.

**Files**: Only production files (e.g., `src/extractor.py`). Never test files.

**Tests field**: Lists the same test criteria as the corresponding test task —
but now they mean "these existing tests must pass after implementation."

**Depends on**: Must include the corresponding test task, plus any other
dependency (scaffold, config, other modules it imports from).

**Acceptance criteria**:
- "All tests in `<test_file>` pass"
- Feature-specific criteria ("function returns X when given Y")
- "Lint passes with zero errors"

**Security considerations**: Include relevant security concerns from the
design doc — this is where they're actionable.

### Example TDD pair

For a SQLite extractor component:

```
task-03 (test, core): "Write extractor tests"
  files: [tests/test_extractor.py]
  tests: [
    "extract_blood_glucose converts mmol/L to mg/dL by multiplying by 18.0182",
    "heart rate joins on parent_key=row_id",
    "since_ms filters records with last_modified_time <= since_ms",
    ...
  ]
  acceptance: ["tests importable", "tests fail — implementation missing", "lint passes"]
  depends_on: [task-01]

task-04 (implementation, core): "Implement SQLite extractor"
  files: [plugins/extractors/parse_health_db.py]
  tests: [same criteria as task-03 — these tests must now pass]
  acceptance: ["all 15 tests pass", "extract_all returns dict with 6 keys", "lint passes"]
  depends_on: [task-01, task-03]
```

### When NOT to create a TDD pair

Some tasks don't have testable logic and only need an `implementation` task:

- **Scaffold tasks**: Creating directories, `__init__.py`, config files
- **Infrastructure tasks**: Dockerfile, compose files, CI config
- **Pure configuration**: Environment variable setup, settings classes with
  no business logic

These tasks use `task_type: "implementation"` with an empty `tests` list.
The schema allows this — it only enforces TDD pairing when an implementation
task has tests.

### Integration-level TDD

For integration tasks (e.g., wiring a DAG), the TDD pair looks different:

- The **test task** writes integration tests (e.g., tests that verify messages
  flow through RabbitMQ end-to-end). These may need test infrastructure
  (docker-compose for RabbitMQ, fixtures for test data).
- The **implementation task** writes the wiring code and depends on both the
  integration test task and all the component tasks it wires together.

If the integration tests need external services (databases, message queues),
note that in the test task's description so the implementing model sets up
the right test infrastructure.

## Writing Acceptance Criteria

Acceptance criteria are the final checkpoint. The implementation pipeline runs
these checks after the model finishes a task. They must be objectively verifiable —
no "code is clean" or "follows best practices".

### Criteria by task type

**Test tasks**:
1. "Test file is syntactically valid and importable"
2. "Tests fail because implementation does not exist yet" (or similar)
3. "Lint passes with zero errors"

**Implementation tasks**:
1. "All tests in `<test_file>` pass"
2. Feature-specific criteria (see below)
3. "Lint passes with zero errors"

### Feature-specific criteria examples

- "Endpoint returns 200 for valid input and 422 for malformed input"
- "Config loads API_KEY from environment variable, not hardcoded"
- "Module can be imported from the package root: `from health_sync import client`"
- "Dockerfile builds successfully with `docker build .`"
- "Migration creates the expected table with columns X, Y, Z"

### Anti-patterns

- **"Code is well-documented"** — Too subjective. Instead: "All public functions
  have docstrings."
- **"Handles errors properly"** — Too vague. Instead: "Network errors raise
  `ConnectionError` with the original error as cause."
- **"Follows project conventions"** — The task description should specify what
  conventions to follow, not leave it to the model to discover.

## Writing Security Considerations

Pull from the design doc's Security Posture section and distribute to the
implementation tasks where each concern is actionable. Security considerations
go on implementation tasks, not test tasks.

### Distribution rules

- **Input validation** → Goes on the implementation task that creates the
  input-handling code
- **Auth token handling** → Goes on the implementation task that creates the
  API client
- **Sensitive data logging** → Goes on any implementation task that adds
  logging near sensitive data
- **SQL injection** → Goes on the implementation task that creates database
  queries
- **CORS / headers** → Goes on the implementation task that creates the API
  endpoint

### Format

Each security consideration should answer two questions:
1. **What's the concern?** (the `concern` field)
2. **What must the implementing model do about it?** (the `mitigation` field)

The mitigation should be specific enough that the model can verify compliance.
"Be careful with auth tokens" is useless. "Read the API token from the
`HEALTH_API_TOKEN` environment variable; never log the token value; use
`token[:4]+'...'` if token presence needs to be logged" is actionable.

## Task Sizing

### Too large (split it)

- More than 5-6 files to create/modify
- Requires understanding multiple subsystems simultaneously
- Has both "create infrastructure" and "write business logic" responsibilities
- Would take a human developer more than 2-3 hours

### Too small (merge it)

- Creates a single config file with no logic
- Just adds an import to an existing file
- Is a one-line change to an existing component
- Would take a human developer less than 10 minutes

### Right-sized

- Creates 1-3 files with a clear, cohesive purpose
- Has a focused responsibility that fits in a single Aider session
- The implementing model can hold the full context in its working memory (~32k tokens)
- Results are independently testable
