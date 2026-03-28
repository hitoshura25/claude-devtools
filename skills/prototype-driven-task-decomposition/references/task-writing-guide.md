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

## Writing Tests

Each `TestCriterion` tells the implementing model: "Write this test and make it pass."

### Test granularity

- **Unit tests**: Test a single function or method in isolation. Mock external
  dependencies.
- **Integration tests**: Test how components work together. May need test
  infrastructure (database, service mocks).
- **E2E tests**: Test the full flow. These usually go in the `testing` phase tasks,
  not alongside individual component tasks.

### Which tasks get tests?

| Task type | Tests? |
|-----------|--------|
| Scaffold (directory setup, config) | Usually no |
| Core (business logic, data models) | Yes — unit tests |
| Integration (wiring, endpoints) | Yes — integration tests |
| Testing (test infrastructure) | No — the task IS the test infrastructure |
| Infrastructure (Dockerfile, CI) | Maybe — smoke test if relevant |

### Tasks verified by downstream tests

Some integration-phase tasks are hard to unit test meaningfully. For example,
a DAG wiring task that connects several components may only be verifiable through
the integration tests written in a later testing-phase task.

This is acceptable, but handle it explicitly:

1. The integration task's `tests` list should be empty (no pretend tests).
2. The integration task's acceptance criteria should focus on **structural checks**
   the pipeline can verify without running the full integration: "DAG imports
   without error", "DAG has exactly 3 tasks", "module-level validation passes".
3. The integration task's description should note: "End-to-end correctness is
   verified by task-NN (integration tests)."
4. The testing-phase task's `depends_on` must include the integration task.

This makes the relationship explicit. The pipeline knows it can only fully verify
the integration task after the testing task runs, and a human reviewer can see
the connection clearly.

### Test file placement

Follow the project's existing test convention. If the project puts tests in
`tests/` at the root, use that. If it co-locates tests with source, do that.
Don't invent a new convention.

## Writing Acceptance Criteria

Acceptance criteria are the final checkpoint. The implementation pipeline runs
these checks after the model finishes a task. They must be objectively verifiable —
no "code is clean" or "follows best practices".

### Required criteria (every task gets these)

1. **"Lint passes with zero errors"** — The schema enforces this automatically.
2. **"All tests pass"** — If the task has tests.

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

Pull from the design doc's Security Posture section and distribute to the tasks
where each concern is actionable.

### Distribution rules

- **Input validation** → Goes on the task that creates the input-handling code
- **Auth token handling** → Goes on the task that creates the API client
- **Sensitive data logging** → Goes on any task that adds logging near sensitive data
- **SQL injection** → Goes on the task that creates database queries
- **CORS / headers** → Goes on the task that creates the API endpoint

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
