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
├── README.md              # What this proves, how to run it, toolchain notes
├── <entry point>          # main.py, main.ts, etc.
├── <supporting files>
├── <lint config>          # .ruff.toml, .eslintrc, etc.
├── <test file(s)>         # test_*.py, *.test.ts, etc.
├── Dockerfile             # Only if containerization is relevant
└── <sample data if needed>
```

The README.md is important — it documents what the prototype is for, so anyone (or
any future model) encountering it understands its purpose without needing the full
conversation history. Include a "Toolchain notes" section documenting any surprises
from lint, test, or container setup (specific lint rules needed, import path quirks,
Docker entrypoint behavior, etc.). These notes feed directly into the design doc.

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

Write the minimum tests needed to validate the prototype's core logic. The goal is
not exhaustive coverage — it's proving the test infrastructure works for this
technology and validating the most important behavior.

**How to approach it:**

1. Identify the core logic the prototype proved — the piece whose correctness
   matters most.
2. Check if the project has an existing test framework. If so, use it.
3. Write minimal tests that validate the chosen logic.
4. Run them and confirm they pass.

"Minimal" means enough to prove the test toolchain works and the core logic is
correct — not one test for the sake of one, but not exhaustive coverage either.
If the prototype has six extractors that all follow the same pattern, testing one
or two is sufficient. If they each have different conversion logic, test each
conversion.

**What to capture for the design doc:**
- Test framework and any plugins needed
- How imports work (can test files import from the prototype cleanly?)
- Fixture patterns needed (e.g., in-memory databases, mock services)
- Any framework-specific gotchas discovered during setup

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

## End-to-End Validation

Running code internally (tests pass, script executes) is necessary but not sufficient.
The prototype must also work *from the outside* — from the perspective of whatever
will actually consume it in production.

The shape of this validation depends on what the prototype is:

### Dockerized service or scheduled job

Don't just build the image — prove you can interact with the running container:

- **Service with an API**: Start the container, make a request, get a response.
  A simple `curl` health check or a single API call is sufficient.
- **Service with a message queue**: Start the container alongside the broker,
  publish a message, confirm it's consumed (or the reverse).
- **Scheduled job / DAG**: Start the runtime environment (e.g., Airflow), trigger
  the job, confirm it completes. For Airflow specifically, this means the DAG
  loads and a task runs — not just "the script works when called directly."
- **Database-backed service**: Start with the real database (or an in-memory
  equivalent), confirm the service connects and responds.

The goal is to prove the container is a functional unit, not just a packaging step.

### Mobile application

- Build the app (APK/IPA or debug build)
- Install it on an emulator or device
- Run a minimal UI test or instrumentation test that confirms a screen renders
  and basic navigation works
- If the prototype involves a new screen or feature, the test should exercise that
  specific screen

This validates the build toolchain, dependency resolution, and basic runtime
behavior — areas where mobile projects frequently surprise you.

### Library or SDK

- Create a minimal consumer project (or test file) outside the library directory
  that imports and calls the library's public API
- Confirm the import resolves and the call produces expected output
- This catches packaging issues (missing `__init__.py`, incorrect exports,
  build configuration problems) that internal tests won't reveal

### CLI tool

- Run the tool end-to-end with real (or realistic) input
- Verify the output matches expectations
- Test at least one error case (bad input, missing file) to confirm error handling
  works from the user's perspective

### What to capture

Document the end-to-end validation result in the README under "Toolchain notes" or
as a separate "End-to-end validation" section. Include:
- Exactly what was tested (the command run, the request made, the test executed)
- What the result was
- Any surprises or configuration needed to make it work

## Handling Blockers

During prototype validation, you will sometimes hit blockers that require user
action — credentials, a running service, hardware access, or permissions. This is
normal and expected for integration risks. The correct response is to ask for help,
not to silently defer the validation.

### The anti-pattern to avoid

When the model encounters a blocker (e.g., "Docker daemon not running" or "no
Google Drive credentials"), the temptation is to:
1. Skip the validation
2. Note it as "not validated" in the findings
3. Defer it to the design doc as an "open question" or "manual validation step"

This defeats the purpose of the prototype. The design doc will then speculate about
the integration instead of observing it — exactly the problem prototype-driven
planning exists to solve.

### What to do instead

1. **Stop and tell the user what you need.** Be specific: "I need Google Drive
   service account credentials to validate the download integration. Do you have
   a service account JSON file I can use?"

2. **Write a smoke test script.** Even if you can't run it yourself, create a small
   standalone script that the user can run with their credentials. Make it easy:
   clear environment variable names, a single command to execute, and output that
   clearly says PASS or FAIL.

3. **Work through the setup together.** If the user provides credentials but the
   first attempt fails (wrong permissions, wrong file path, API error), iterate
   together. These failures are *exactly* the discoveries the prototype exists to
   surface.

4. **Only mark as "not validated" if the user explicitly defers.** If the user says
   "I don't have credentials for that" or "skip the Drive integration for now,"
   that's a valid decision. Document it clearly in the Phase 2 report as an
   unvalidated integration risk that the design doc cannot ground in reality.

### Common blockers and how to handle them

| Blocker | Wrong response | Right response |
|---|---|---|
| Credentials not available | "Drive download not validated — deferred to design doc" | "I need a service account JSON. Do you have one? I'll write a smoke test script." |
| Docker not running | "Alternative validation: import chain test" | "Can you start Docker? I need to run the DAG inside Airflow to validate end-to-end." |
| External service unreachable | "Mocked the service interaction" | "The RabbitMQ broker needs to be running. Can you start it with `docker compose up rabbitmq`?" |
| Hardware not available | "Skipped device test" | "I need an Android emulator to validate the UI test. Is one available, or should we defer this specific validation?" |

The key insight: the user is a collaborator, not an observer. They have access to
credentials, services, and hardware that the model doesn't. Asking for help is
correct behavior, not a failure.

### When deferral is genuinely OK

Sometimes deferral is the right call:
- The user explicitly says to skip it
- The resource genuinely doesn't exist yet (e.g., a production database that
  hasn't been provisioned)
- The validation requires infrastructure that's impractical for a prototype
  (e.g., a full Kubernetes cluster)

In these cases, document the unvalidated risk clearly in the Phase 2 report and
the design doc. The design doc should flag it as "not validated by prototype —
this section is based on research, not observation."

## Researching Cross-Cutting Concerns

After the core code, toolchain, and end-to-end validation are complete, research
remaining concerns. The prototype gives you real context — you now know what the
technology actually requires.

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

Beyond the tests already written, research:

- Integration test patterns for this technology
- Service-gated vs mocked test strategies
- Any test infrastructure the project already has that can be reused
