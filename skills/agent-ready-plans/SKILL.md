---
name: agent-ready-plans
description: Decompose implementation plans into individual task files for smaller AI coding agents like aider running local models (Qwen Coder, Codestral) via LMStudio. Claude Code writes and validates the tests; the small model implements the code to make them pass. Use this skill whenever someone says "decompose this plan", "break this into aider tasks", "create task files for local agents", "make this plan agent-ready", or wants to delegate implementation to smaller models. Also trigger when a user has a design doc + implementation plan and mentions aider, LMStudio, local models, or task decomposition — even if they don't explicitly say "agent-ready".
---

# Agent-Ready Plans

Translate a design document + implementation plan into self-contained task files that smaller AI coding agents can execute sequentially. Each task is an aider `--message-file` with an interface contract, behavioral specs, and pre-written tests — everything a small model needs to implement and test one component.

The key insight: Claude Code writes complete, verified tests for each task. The small model implements the code to make them pass. Claude Code owns test correctness — the small model owns implementation. This gives the small model a concrete, verifiable success criterion without relying on its ability to write correct tests from vague specs.

Announce at start: "I'm using the agent-ready-plans skill to break this plan into individual task files."

## Inputs

1. **Design document** — the "what and why" (architecture, data model, decisions)
2. **Implementation plan** — the "how" (phased tasks with interface contracts, behavioral specs, test scenarios)

Both are typically markdown files in `docs/plans/`.

## Output

A subfolder next to the plan file, named after the plan (strip the date prefix and `-implementation` suffix).

Example: `docs/plans/2026-01-29-my-service-implementation.md` produces:

```
docs/plans/my-service-tasks/
├── 00-manifest.json
├── 01-task-2.1-settings.md
├── 02-task-2.2-base-component.md
├── ...
├── lint.sh          (if needed for this language)
└── run-tasks.sh
```

Note: task numbering starts at Phase 2 because Phase 1 (scaffold) is created directly by Claude Code in Step 3.

Each plan gets its own uniquely-named folder — reusing a generic `tasks/` directory causes collisions when decomposing multiple plans.

## Process

### 0. Check for Stale Git Artifacts — Do This First

Before touching anything, check whether output files from a previous run exist in git history:

```bash
git ls-tree -r HEAD --name-only | grep "docs/plans/.*-tasks/"
```

If previous task files, scaffold files, or a runner script appear in HEAD, **do not restore them with `git checkout HEAD`**. Those files are stale — the user deleted them intentionally to trigger a fresh regeneration incorporating skill updates. Restoring from git silently skips all skill improvements made since the last run.

Instead: proceed with the full process from Step 1. Generate everything fresh from the current skill files. The git history is context only — not a shortcut.

### 1. Read and Analyze

Read both the design doc and implementation plan. Build a mental model of total tasks, dependencies between phases, interface contracts, and the project's language/tooling.

### 2. Determine Test & Lint Tooling

Identify the lint and test commands for the project. These power aider's `--auto-lint` and `--auto-test` flags, which automatically validate every task's output — this is how errors get caught.

Read `references/tooling.md` for the discovery process and manifest format. Then read the appropriate `references/stacks/<language>-<framework>.md` for language-specific install commands, lint wrapper setup, and whether a wrapper is needed for your linter.

### 3. Set Up Tooling and Scaffold (execute directly)

This is the most important step for reliability. Install tooling and create the project scaffold *right now*, directly in the current Claude Code session — do not delegate these to task files for the small model.

Small models can write business logic code, but they can't debug missing tool installations, broken configs, environment issues, or subtle test setup patterns. Claude Code can. By handling setup and scaffold here, every subsequent task starts with a working foundation.

**Tooling setup:** Read `references/tooling.md` and `references/stacks/<language>-<framework>.md`. Investigate the project's existing conventions first (package manager, monorepo structure), then set up tooling consistently with what's already there.

**Project scaffold:** The implementation plan lists scaffold files in its "Scaffold" section (typically Phase 1). Create these files directly:
- Build/package config with all dependencies, test config, and lint config
- Test setup file with fixtures (see below)
- All package `__init__` files or equivalent for the language
- Any other foundation files the plan specifies
- A stub file for each task (see Step 3b below)

**Stub files must not execute code that requires runtime environment.** Any module that defines a module-level singleton must stub that line as null/None. Other stubs that import from it will import null cleanly instead of triggering the constructor. If the constructor requires env vars, files, or network and they are absent, test collection fails for every transitively-importing test file. See `references/writing-guide.md` § "Stub Design" and the stack file for language-specific examples.

The scaffold is critical because it establishes the testing foundation. Two categories of fixtures belong here:

**Framework collection fixtures:** Autouse fixtures for mocking frameworks not installed in dev. These must work at test collection time — not just at test execution time. Small models don't understand the distinction.

**External dependency mock fixtures:** Reusable fixtures for external service clients (cloud storage, message brokers, database drivers, etc.). These libraries have complex APIs requiring precise mock wiring. Small models consistently fail to mock these correctly, spending all their reflections debugging mock plumbing instead of writing business logic. Read `references/tooling.md` § "Creating External Dependency Mock Fixtures" and the stack file for language-specific examples.

After setup, verify both lint and test commands pass (even if no tests exist yet — the test runner should exit cleanly). Do NOT commit or stage any files — the user manages git operations.

### 3b. Write and Validate Task Tests

For each task in the plan, write its test file now — before generating task documents. The small model's job is to make these tests pass. Claude Code owns test correctness.

Read `references/writing-guide.md` § "Writing Correct Tests" for the full rules. Key requirements:

**Write tests against stubs, then validate with the mutation gate:**

1. Create a minimal stub implementation for each task's module — classes/functions that exist and are importable, but return null or raise "not implemented". This gives the mutation tool something to mutate and satisfies import resolution.
2. Write the test file for the task against the stub.
3. Run the **mutation gate** on the stub + tests. See `references/tooling.md` § "Mutation Testing" for the language-specific tool and commands. Surviving mutants mean weak assertions — strengthen the tests.
4. Run the test suite against the stub. **Verify that all tests fail, and fail for the right reason:** "not implemented" error, assertion failure, or wrong return value — never import/module errors or fixture setup errors (those indicate broken test infrastructure, not missing implementation).
5. Once the mutation gate passes and failures are correct, replace stub bodies with "not implemented" (do not delete the files, since imports must still resolve).

This two-layer gate — mutation score + correct failure mode — is the mechanical check that tests will actually catch bugs in the small model's implementation.

**Record validation results in the manifest** (Step 6): each task entry gets `"pre_validated": true` and a `"test_file"` field after this step passes. The runner asserts this field before executing a task.

### 4. Extract Project Context

Extract a shared context block from the design doc (10-15 lines max). This gets embedded at the top of every task file so the small model understands the project without needing the full design doc.

Include: what the project does (1-2 sentences), tech stack, key directory structure, lint/test commands, naming conventions, and available test fixtures (so the model uses them instead of writing its own mocks). Always end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.`

### 5. Generate Task Documents

For each task in the implementation plan (starting from Phase 2 — Phase 1 scaffold was created in Step 3), generate a standalone markdown file. Read `task-template.md` for the complete template structure.

**Naming:** `NN-task-X.Y-short-description.md` where NN is the zero-padded execution order (starting from 01), X.Y is the original task number, and the description is kebab-case.

Key principles for task docs:

- **Self-contained.** Inline all relevant context. The model shouldn't need to look at other files or tasks to understand what to do.
- **Explicit file paths** from project root. Never relative, never ambiguous.
- **Interface contracts, not implementation code.** Provide class/function names, method signatures with type annotations, and behavioral specs. Do not include method bodies.
- **Tests are pre-written by Claude Code.** The actual test code is in the `## Tests` section (written in Step 3b). Remove prose `## Test Scenarios` — replace with the `## Tests` section containing the real test file.
- **Component tasks create files only — never modify shared files.** A component task's `## Files to Create` lists only the new source file and its test file. It never has a `## Files to Modify` or `## Wiring` section. Modifications to shared orchestrating files (DAGs, routers, registries, dispatchers) are collected into dedicated wiring tasks in a later phase. See `references/writing-guide.md` § "Task Scope: Component Tasks vs Wiring Tasks".
- **Test commands are scoped to the task's own test file.** The `test_command` in the manifest runs only the test file the task creates. Never include shared orchestrator test files (e.g., `test_dag.py`) in a component task's `test_command` — a broken orchestrator would cascade-fail all downstream tasks whose implementations are individually correct.
- **Environment constraints.** State what's mocked, what's not installed, what can't make real connections.
- **One commit per task** with a conventional commit message.

**Deferred tasks vs service-gated tasks:** These are distinct categories — do not conflate them.

- A task is `"deferred": true` only when its doc genuinely cannot be written upfront, because its content depends on runtime artifacts from earlier tasks (e.g. actual class names, actual module paths produced by the small model). Deferred tasks cause the runner to halt and wait for Claude Code to generate the doc from actual produced code.
- A task uses `"requires_services": [...]` when its doc can be fully written upfront but its execution requires live external services (databases, message brokers, object stores). The runner skips these tasks (with a warning) when services are unavailable, and runs them automatically when services are reachable. Integration tests belong in this category.

See `references/writing-guide.md` § "Deferred Tasks vs Service-Gated Tasks" for full guidance and manifest examples.

Read `references/writing-guide.md` for deeper guidance on writing style, splitting large tasks, complexity ratings, and deferred task identification.

### 6. Generate the Manifest

Create `00-manifest.json` with task metadata and a `tooling` section:

```json
{
  "plan_source": "docs/plans/...-implementation.md",
  "design_source": "docs/plans/...-design.md",
  "generated_at": "2026-01-29T18:00:00Z",
  "total_tasks": 25,
  "tooling": {
    "lint_cmd": "<lint command or wrapper path>",
    "test_cmd": "<global test command>",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  },
  "tasks": [
    {
      "file": "01-task-2.1-settings.md",
      "task_id": "2.1",
      "title": "Settings",
      "phase": "Core Abstractions",
      "files_created": ["services/my-service/config/settings.py",
                         "services/my-service/tests/test_settings.py"],
      "files_modified": [],
      "test_command": "cd services/my-service && uv run pytest tests/test_settings.py -x -q",
      "test_file": "services/my-service/tests/test_settings.py",
      "pre_validated": true,
      "estimated_complexity": "simple"
    },
    {
      "file": "18-task-6.1-wire-components.md",
      "task_id": "6.1",
      "title": "Wire All Extractors into DAG",
      "phase": "Wiring",
      "files_created": [],
      "files_modified": ["services/my-service/dags/pipeline.py",
                          "services/my-service/tests/test_dag.py"],
      "test_command": "cd services/my-service && uv run pytest tests/test_dag.py -x -q",
      "estimated_complexity": "moderate",
      "deferred": false,
      "depends_on": ["2.1", "2.2", "3.1", "4.1", "4.2", "5.1"]
    },
    {
      "file": "20-task-8.1-integration-test.md",
      "task_id": "8.1",
      "title": "Pipeline Integration Tests",
      "phase": "Integration Testing",
      "files_created": ["services/my-service/tests/test_integration.py"],
      "files_modified": [],
      "test_command": "cd services/my-service && uv run pytest tests/test_integration.py -x -q",
      "estimated_complexity": "complex",
      "deferred": false,
      "requires_services": ["minio", "rabbitmq"],
      "service_check_commands": {
        "minio": "curl -sf http://localhost:9000/minio/health/live",
        "rabbitmq": "curl -sf http://localhost:15672/api/overview -u guest:guest"
      },
      "depends_on": ["6.1"]
    }
  ]
}
```

### 7. Generate the Runner Script

Copy `scripts/run-tasks-template.sh` verbatim into the output folder as `run-tasks.sh`. Do NOT rewrite it or generate a new script — the template is the correct, tested implementation.

**Do not restore `run-tasks.sh` from git history.** Always copy from `scripts/run-tasks-template.sh` — git HEAD may contain an older version that predates skill updates.

After copying, make exactly two targeted edits if needed:
- `DEFAULT_MODEL` — update if the project uses a different local model
- `PROJECT_ROOT` path calculation — update if the tasks folder is not 3 levels below the project root

### 8. Present Results

Summarize what was generated: scaffold created, N task files + M service-gated, manifest, runner. Include the phase breakdown and the commands to run.

## Execution Notes

Generate task files sequentially in the main session. Write each file to disk before moving to the next. Show progress as you go.

## Bundled Resources

| Resource | When to read |
|----------|-------------|
| `task-template.md` | Step 5 — complete template with all sections |
| `references/tooling.md` | Steps 2, 3, 3b — tooling discovery, fixture criteria, mutation gate |
| `references/stacks/<language>-<framework>.md` | Steps 2, 3, 3b — language-specific install commands, lint wrapper, fixture examples, stub patterns, mutation tool |
| `references/writing-guide.md` | Steps 3b, 5 — test correctness rules, stub design, task scope rules, deferred/service-gated task guidance |
| `scripts/lint-ruff-wrapper.sh` | Step 3, Python/ruff projects — copy into tasks folder, update `RUFF_BIN` |
| `scripts/run-tasks-template.sh` | Step 7 — copy verbatim, make two targeted edits |
