---
name: implementation-planning
description: Design features and produce validated implementation plans with working scaffold, stubs, and tests on disk. Use this skill whenever someone says "plan this feature", "design and plan", "I need an implementation plan", "help me plan", or has a feature idea that needs to go from concept to actionable implementation. Also trigger when someone mentions wanting to use local models, aider, or task decomposition — even if they don't explicitly ask for a "plan". This skill produces the design doc, implementation plan, AND validated scaffold (stubs, tests, lint scripts, Dockerfile) — everything needed before code implementation begins. Use devtools:agent-ready-plans afterward to package the validated artifacts into task files for coding agents.
---

# Implementation Planning

Turn a feature idea into a design document, implementation plan, and validated scaffold. The plan defines the decomposition, phasing, and behavioral intent. The scaffold proves it works: stubs match interface contracts, tests validate against stubs, lint passes, and infrastructure builds.

This skill produces three categories of output:
1. **Design document** — the what and why (architecture, data model, decisions)
2. **Implementation plan** — the how (phased tasks with behavioral specs, test scenarios, and wiring steps)
3. **Validated scaffold on disk** — stubs, tests, conftest fixtures, lint scripts, Dockerfile, smoke test scripts — all verified working

The validated artifacts on disk are the source of truth. The plan provides decomposition and intent; the scaffold is the ground truth that downstream consumers (agent-ready-plans, Claude Code, or any implementing agent) read directly.

Announce at start: "I'm using the implementation-planning skill to design, plan, and validate the scaffold for this feature."

## Process

### 1. Explore the Idea

Use `superpowers:brainstorming` for the design exploration phase — understanding project context, asking focused questions, proposing approaches with trade-offs, and reaching a shared understanding of what's being built.

**Scope boundary:** Use brainstorming *only* through its design document output. Once the design doc is saved to `docs/plans/YYYY-MM-DD-<feature-name>-design.md`, stop the brainstorming workflow and return here to Step 2. Do not follow the brainstorming skill's "After the Design" section. Also skip any git commit steps from brainstorming — do not commit, stage, or add files unless the user explicitly asks.

If the user already has a design document (or provides enough context to skip brainstorming), move directly to Step 2.

### 2. Write the Implementation Plan

Read `references/plan-format.md` for the complete plan structure, task template, and formatting.

The plan defines decomposition, phasing, dependencies, and behavioral intent. It does NOT produce authoritative code blocks — those come from the validated stubs in Step 4.

**Key principles:**

- **Behavioral specs, not code blocks.** Describe what each component does precisely enough to write tests against, but don't prescribe interface code. The stubs produced in Step 4 are the code-level authority.
- **Test scenarios for test writing.** Describe what to set up and assert concretely enough that correct tests can be derived. See `references/plan-format.md` § "Writing Test Scenarios".
- **Environment constraints, not mock instructions.** State what's mocked and what can't make real connections.
- **Complete wiring.** Every component must be wired into whatever consumes it. Read `references/wiring-completeness.md`.
- **Exact file paths** from project root. Never "create a config file" — always "create `services/my-service/config/settings.py`".
- **Scaffold as a separate concern.** Phase 1 (project scaffold) is created directly in Step 3, not delegated.
- **Service-gated tasks, not deferred.** Integration tests use `Requires services:` — not deferred.

Save to `docs/plans/YYYY-MM-DD-<feature-name>-implementation.md`.

**No automatic git operations.** Do not commit, stage, or add files to git unless the user explicitly asks.

### 3. Set Up Tooling and Scaffold

Install tooling and create the project scaffold *now* — do not delegate these. Implementing models can write business logic but can't debug missing tools, broken configs, or subtle test setup.

#### 3a. Tooling Setup

Read `references/tooling.md` for the discovery process. Then read the appropriate `references/stacks/<language>-<framework>.md`.

**Scan for infrastructure tasks:** Check whether any task's `files_created` includes `Dockerfile`, `*compose*.yml`, `*.tf`, or Kubernetes YAML. If infrastructure tasks are present:
- Install `hadolint` (see `stacks/infra.md` § "Tooling Setup")
- Copy `scripts/infra-lint-wrapper-template.sh` → tasks folder as `infra-lint.sh`
- For each Docker/compose task, copy `scripts/docker-smoke-test-template.sh` and configure `COMPOSE_FILE` and `HEALTH_URL`

#### 3b. Conftest Fixtures

Read `references/stacks/<language>/fixture-patterns.md` (e.g., `python-pytest/fixture-patterns.md`). For each external dependency, pick the appropriate pattern (capture mock, client mock, or stateful fake), copy the template, and adjust patch paths. Follow the fixture interaction rules.

#### 3c. Project Scaffold

Create these files directly:
- Build/package config with all dependencies, test config, lint config
- Test setup file with fixtures (from fixture-patterns.md templates)
- All package `__init__` files
- Copy `scripts/lint-ruff-wrapper.sh` → tasks folder as `lint.sh` (or appropriate lint wrapper for the language)
- A stub file for each task (see Step 4)
- Integration test file(s) — write the complete integration tests during scaffold, not as an implementing-model deliverable. Integration tests exercise the same code the unit tests cover but against live services. They are service-gated (can't run without services) but must be lint-clean and syntactically valid. Validate with Layer 0 (lint) only.

#### 3d. Infrastructure Scaffold (if applicable)

Read `stacks/infra.md` § "Step 0: Research the base image's Docker setup" and § "Dockerfile and Test Compose as Scaffold".

- Research the base image's official Docker documentation — entrypoint behavior, initialization mechanisms, environment variables, volume/permission requirements
- Verify base image tags via `docker manifest inspect`
- Write the Dockerfile using the framework's intended startup mechanism
- Build unpinned first, capture resolved versions via `pip freeze`, pin them, rebuild
- Run hadolint against the Dockerfile
- Write the services compose (dependency services only) and the full test compose (includes services compose + adds the app container)
- Verify both with `docker compose up -d --wait` and tear down

#### 3e. Scaffold Verification Checklist

Execute every step before proceeding to Step 4:

1. **Install dev dependencies:** Run `uv sync` (or equivalent) from the service root. Verify the test runner is installed: e.g., `uv run pytest --version` must succeed.
2. **Set lint script permissions:** Run `chmod +x` on every lint wrapper script. The scripts must be executable.
3. **Verify lint works:** Run the lint command from the project root against a stub file — e.g., `./docs/plans/my-tasks/lint.sh services/my-service/plugins/stub.py`. It must execute without "No such file or directory" errors. Note the `./` prefix — this is required.
4. **Verify test works:** Run the test command from the project root — e.g., `cd services/my-service && uv run pytest tests/test_stub.py -x -q`. It must find the test runner and execute (tests may fail against stubs — that's expected; the command itself must not error).
5. **Verify manifest paths match:** Confirm `lint_cmd` starts with `./` and matches the actual script path. Confirm `test_cmd` includes the correct `cd` prefix.

Do NOT proceed to Step 4 until all five checks pass. Do NOT commit or stage any files.

### 4. Write and Validate Tests

For each task, write its test file to disk now — before anyone generates task documents.

Read `references/test-writing-guide.md` for the full rules including the Three-Layer Validation Gate.

**For service tasks:**

1. Write the test file against the stub
2. **Check fixture interaction rules** — verify in the fixture-patterns reference that fixture combinations are valid
3. Run the mutation gate (see `references/tooling.md` § "Mutation Testing")
4. **Run the stub validation script** — do NOT pipe output through `| tail` or `| head`:
   ```bash
   cd <project-root> && bash <path-to-skill>/scripts/validate-stubs.sh <service-root>
   ```
   The script writes full output to both the console AND a timestamped log file (in the scripts/ directory). If any failures need investigation, **read the log file** for complete tracebacks rather than re-running pytest manually with truncated pipes.

   The script handles:
   - Runs each test file individually (no batch output truncation)
   - Sets `COLUMNS=300` to prevent pytest 9.x from truncating error types
   - Detects `assert X == Y` lines without explicit `AssertionError` prefix
   - Accepts only `NotImplementedError` and `AssertionError`; rejects all other failure types
   - All test files are validated, including integration tests — if an integration test can't be collected without live services, that's a test design bug to fix (use per-test conditional skips, not module-level `pytest.exit()`)

   **Do NOT proceed until this script exits 0.** If it reports invalid failures, read the log file for full tracebacks, fix the stub or test, and re-run. Do NOT work around failures by changing test structure (e.g., converting `pytest.exit()` to `skipif` to avoid the error).
5. Replace stub bodies with "not implemented" once all gates pass

**Every test function must be complete.** Test functions must never contain `raise NotImplementedError` — only stubs do. If you cannot finish writing all tests (due to context limits, usage limits, or complexity), stop and tell the user rather than leaving incomplete test functions. The validation script rejects test files that contain `raise NotImplementedError` in test function bodies.

**For infrastructure tasks:**

1. Verify the Dockerfile and test compose are on disk (created in Step 3d as scaffold)
2. Confirm the smoke test script is configured correctly
3. Run the smoke test; confirm it fails on health timeout (not build failure or container crash)
4. Clean up: `docker rmi test-build-verify 2>/dev/null || true`

**Record validation results** for the manifest: service tasks get `"pre_validated": true` and `"test_file"`. Infrastructure tasks get `"pre_validated": true` but no `"test_file"`.

### 5. Validate the Plan

Walk through the wiring completeness checklist in `references/wiring-completeness.md`:

- Every file created in the plan is consumed, imported, or registered somewhere
- Every registry, factory, router, or dispatcher gets updated when new entries are added
- Cross-phase dependencies are explicit (not implied by task ordering)
- Integration tests use `Requires services:` — not marked as deferred
- Deployment tasks specify both a production compose and a self-contained test compose
- Every task's test scenarios are specific enough to verify the behavioral specs

If gaps are found, update the plan and adjust stubs/tests as needed.

### 6. Hand Off

Present the completed artifacts and offer the choice:

```
Design:    docs/plans/YYYY-MM-DD-feature-name-design.md
Plan:      docs/plans/YYYY-MM-DD-feature-name-implementation.md
Scaffold:  On disk — stubs, tests, conftest, lint scripts validated ✅
Infra:     Dockerfile built + pinned, test compose verified ✅ (if applicable)

Phase breakdown:
  Phase 1: Project Scaffolding    — created directly (on disk)
  Phase 2: Core Components        — 4 tasks (stubs + tests validated)
  ...
  Phase 7: Deployment             — 1 task (Dockerfile + test compose on disk)
  Phase 8: Integration Tests      — 2 tasks (service-gated)

Ready to package into agent-ready task files now, or would you
prefer to review the plan and scaffold first?
```

If the user wants to proceed immediately, use `devtools:agent-ready-plans` with the design doc and implementation plan as inputs. The agent-ready skill will read the validated stubs and tests directly from disk. If they want to review first, point them to the files and remind them they can trigger packaging later.

## What This Skill Does NOT Do

- Does not implement business logic (only stubs)
- Does not create task doc files (that's agent-ready-plans)
- Does not create the runner script (that's agent-ready-plans)
- Does not commit, stage, or add files to git

## Bundled Resources

| Resource | When to read |
|----------|-------------|
| `references/plan-format.md` | Step 2 — plan structure, task template, phasing guidelines |
| `references/wiring-completeness.md` | Steps 2, 5 — checklist for registration gaps |
| `references/tooling.md` | Steps 3, 4 — tooling discovery, fixture criteria, mutation gate |
| `references/test-writing-guide.md` | Step 4 — test correctness, validation gates, stub design |
| `references/stacks/<language>-<framework>.md` | Steps 3, 4 — language-specific tooling and traps |
| `references/stacks/<language>/fixture-patterns.md` | Step 3b — fixture templates, interaction rules |
| `references/stacks/infra.md` | Steps 3d, 4 — Docker/compose/Terraform tooling |
| `scripts/lint-ruff-wrapper.sh` | Step 3c, Python/ruff — copy to tasks folder |
| `scripts/infra-lint-wrapper-template.sh` | Step 3a, infra tasks — copy as `infra-lint.sh` |
| `scripts/docker-smoke-test-template.sh` | Step 3a, Docker tasks — copy per service |
| `scripts/validate-stubs.sh` | Step 4 — automated Layer 2 validation gate (run, do not modify) |
