# Phase 2: Tracer Bullet Prototype — Detailed Guidance

## Building the Prototype

The prototype lives in `prototypes/<feature-name>/` within the project. It should be
self-contained enough to run independently but can import from the existing project
when that's part of what's being validated.

### Ground rules

- **Minimum viable code only.** Write the least code that proves the core technical
  risk. If you're testing whether an API returns the right data format, you don't
  need a full service — a script that calls the API and prints the response is enough.

- **Follow existing project conventions.** If the project uses Python with type hints,
  the prototype uses type hints. If it uses a specific import style, match it. The
  prototype is a reference artifact — its patterns will be copied into production code.

- **No premature abstraction.** If you need a database connection, open a database
  connection. Don't build a connection pool manager. The design doc will specify
  the right abstraction based on what the prototype revealed about actual usage
  patterns.

- **Include a way to run it.** Every prototype needs a clear entry point. A script
  with a `if __name__ == "__main__"` block, a shell script, a Makefile target —
  something concrete that demonstrates how to execute the prototype.

### Directory structure

The prototype should look like a minimal but real project:

```
prototypes/<feature-name>/
├── README.md              # What this proves, how to run it
├── <entry point>          # main.py, main.ts, etc.
├── <supporting files>
├── <lint config>          # .ruff.toml, .eslintrc, etc.
├── <test file(s)>         # test_*.py, *.test.ts, etc.
├── Dockerfile             # Only if containerization is relevant
└── <sample data if needed>
```

The README.md is important — it documents what the prototype is for, so anyone (or
any future model) encountering it understands its purpose without needing the full
conversation history.

## Running and Iterating

The prototype must execute successfully. This is non-negotiable.

### Iteration loop

1. Write the code
2. Run it
3. If it fails: read the error, fix the code, go to step 2
4. If it succeeds: verify the output actually proves the core risk

### Common failure patterns

- **Missing dependencies**: Install them. Note what was needed — this informs the
  design doc's dependency section.
- **Authentication issues**: Note the auth pattern required. This is valuable data
  for the design doc.
- **Data format mismatches**: The prototype just revealed something the documentation
  didn't make clear. Capture this in the prototype's README.
- **Environment configuration**: Note what environment setup was needed. This feeds
  directly into the containerization section of the design doc.

### What counts as "working"

The prototype works when:
- It executes without errors
- Its output demonstrates that the core technical risk is resolved
- You can explain what it proved in one sentence

If you can't explain what it proved, the prototype scope was wrong. Re-scope and
rebuild rather than pushing forward with unclear results.

## Toolchain Validation

After the core code works, validate the development toolchain. These steps are just
as important as the core code — they ground the design doc's testing and
containerization sections in proven reality rather than speculative recommendations.

### Lint Setup

Set up linting for the prototype code. The goal is to prove that the lint toolchain
works for this technology and discover any configuration quirks.

**How to approach it:**

1. Check if the project already has a linter configured. If so, use the same tool
   and extend/adapt its config for the prototype code.
2. If no existing linter, choose the standard one for the language (ruff for Python,
   eslint for TypeScript, clippy for Rust, etc.).
3. Configure it in the prototype directory.
4. Run it against the prototype code.
5. Fix all issues until the linter passes clean.

**What to capture for the design doc:**
- Which linter and version
- Any configuration tweaks needed for this technology (e.g., specific rules to
  disable, import ordering settings)
- Any surprising lint issues that required code changes

### Minimal Test Setup

Write one test for one piece of core logic. The goal is not test coverage — it's
proving the test infrastructure works for this technology.

**How to approach it:**

1. Pick the most important piece of logic the prototype proved (e.g., a data parser,
   a conversion function, a query builder).
2. Check if the project has an existing test framework. If so, use it.
3. Write one test that validates the chosen logic.
4. Run it and confirm it passes.

**What to capture for the design doc:**
- Test framework and any plugins needed
- How imports work (can test files import from the prototype cleanly?)
- Fixture patterns needed (e.g., in-memory databases, mock services)
- Any framework-specific gotchas (e.g., Airflow imports need sys.modules patching)

**Common trap:** Writing the test is easy; getting the test infrastructure configured
correctly is where the surprises live. Pay attention to import paths, fixture
discovery, conftest placement, and plugin compatibility.

### Dockerfile (Conditional)

A Dockerfile is only relevant if the feature involves a deployable service, scheduled
job, or infrastructure component that will be containerized.

**When to include a Dockerfile:**
- The feature is a new service (API server, worker, DAG runner, etc.)
- The feature is a scheduled job (cron, Airflow DAG, etc.)
- The feature requires specific runtime infrastructure (database, message broker, etc.)
- The project's existing deployment pattern uses Docker

**When to skip:**
- The feature is a library or SDK
- The feature is a CLI tool that runs on the developer's machine
- The feature is a mobile application
- The feature adds functionality to an existing service (the existing Dockerfile covers it)
- The feature is a configuration change or infrastructure-as-code

**How to approach it (when applicable):**

1. Research the base image's official Docker documentation. This is critical and
   technology-specific — entrypoint behavior, built-in initialization mechanisms,
   environment variables, and volume/permission requirements vary by image.
2. Write the Dockerfile in the prototype directory.
3. Build it. Fix any build errors.
4. Start the container. Verify it runs (the prototype entry point executes, the
   service starts, etc.).
5. Note any surprises — unexpected entrypoint behavior, required environment
   variables, permission issues.

**What to capture for the design doc:**
- Base image and version
- Entrypoint behavior (what the official docs say vs what actually happened)
- Required environment variables at runtime
- Health check approach
- Any build-time gotchas (dependency installation order, layer caching, etc.)

## Researching Cross-Cutting Concerns

After the core code and toolchain are validated, research remaining concerns. The
prototype gives you real context — you now know what the technology actually requires.

### Security-by-Design

Based on what the prototype revealed about data flow and external interactions:

- What input validation is needed?
- Are there authentication/authorization concerns?
- Does the feature handle sensitive data that needs encryption or access controls?
- Are there known security gotchas with this technology?

### Deployment Considerations

- How does this feature integrate with the existing deployment pipeline?
- Are there new infrastructure dependencies?
- Does it need configuration management?
- Are there rollback considerations?

### Additional Testing Patterns

Beyond the single test already written, research:

- Integration test patterns for this technology
- Service-gated vs mocked test strategies
- Any test infrastructure the project already has that can be reused
