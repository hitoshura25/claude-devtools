---
name: agent-ready-plans
description: Decompose implementation plans into individual task files for smaller AI coding agents like aider running local models (Qwen Coder, Codestral) via LMStudio. Claude Code writes and validates the tests; the small model implements the code to make them pass. Use this skill whenever someone says "decompose this plan", "break this into aider tasks", "create task files for local agents", "make this plan agent-ready", or wants to delegate implementation to smaller models. Also trigger when a user has a design doc + implementation plan and mentions aider, LMStudio, local models, or task decomposition — even if they don't explicitly say "agent-ready".
---

# Agent-Ready Plans

Translate a design document + implementation plan into self-contained task files that smaller AI coding agents can execute sequentially. Each task is an aider `--message-file` with an interface contract, behavioral specs, and test scenarios — everything a small model needs to implement and test one component.

The key insight: Claude Code writes complete, verified tests for each task. The small model implements the code to make them pass. Claude Code owns test correctness — the small model owns implementation. This gives the small model a concrete, verifiable success criterion without relying on its ability to write correct tests from vague specs.

Announce at start: "I'm using the agent-ready-plans skill to break this plan into individual task files."

## Inputs

1. **Design document** — the "what and why" (architecture, data model, decisions)
2. **Implementation plan** — the "how" (phased tasks with interface contracts, behavioral specs, test scenarios)

Both are typically markdown files in `docs/plans/`.

## Output

A subfolder next to the plan file, named after the plan (strip the date prefix and `-implementation` suffix).

Example: `docs/plans/2026-01-29-airflow-google-drive-ingestion-implementation.md` produces:

```
docs/plans/airflow-google-drive-ingestion-tasks/
├── 00-manifest.json
├── 01-task-2.1-pydantic-settings.md
├── 02-task-2.2-base-record-extractor.md
├── ...
├── lint.sh
└── run-tasks.sh
```

Note: task numbering starts at Phase 2 because Phase 1 (scaffold) is created directly by Claude Code in Step 3.

Each plan gets its own uniquely-named folder — reusing a generic `tasks/` directory causes collisions when decomposing multiple plans.

## Process

### 1. Read and Analyze

Read both the design doc and implementation plan. Build a mental model of total tasks, dependencies between phases, interface contracts, and the project's language/tooling.

### 2. Determine Test & Lint Tooling

Identify the lint and test commands for the project. These power aider's `--auto-lint` and `--auto-test` flags, which automatically validate every task's output — this is how errors get caught.

Read `references/tooling.md` for common commands by language and the manifest format.

### 3. Set Up Tooling and Scaffold (execute directly)

This is the most important step for reliability. Install tooling and create the project scaffold *right now*, directly in the current Claude Code session — do not delegate these to task files for the small model.

Small models can write business logic code, but they can't debug missing tool installations, broken configs, environment issues, or subtle conftest patterns. Claude Code can. By handling setup and scaffold here, every subsequent task starts with a working foundation.

**Tooling setup:** Read `references/tooling.md` for the full discovery and setup process. The key idea: investigate the project's existing conventions first (package manager, virtual environment, monorepo structure), then set up tooling in a way that's consistent with what's already there.

Three things to get right during tooling setup (all covered in `references/tooling.md`):
- **Install project dependencies**, not just lint/test tools. Tests will fail with `ModuleNotFoundError` if only ruff and pytest are installed but the project's libraries are missing.
- **Use the lint wrapper script** (`scripts/lint-ruff-wrapper.sh` for Python/ruff projects). Aider appends every edited filename to the lint command, including non-Python files like `requirements.txt` that ruff can't parse. The wrapper filters to `.py` files only and runs ruff with `--fix` so trivial issues (import sorting, unused imports) are auto-corrected.
- **Avoid `cd` in the lint command.** Aider appends file paths relative to the project root, which break after a directory change. The wrapper handles this. Test commands can use `cd` since aider runs them as-is.

**Project scaffold:** The implementation plan lists scaffold files in its "Scaffold" section (typically Phase 1). Create these files directly:
- `pyproject.toml` with all dependencies, pytest config, and ruff config
- `conftest.py` with test fixtures (see below)
- All `__init__.py` files for the package structure
- Any other foundation files the plan specifies
- A stub file for each task (see Step 3b below)

**Stub files must not execute code that requires runtime environment.** Any module that defines a module-level singleton (e.g., `settings = Settings()`) must stub that line as `settings = None`. Other stubs that import from it (e.g., a DAG stub that does `from plugins.config.settings import settings`) will then import `None` cleanly instead of triggering the constructor. If the constructor requires env vars, files, or network and they are absent, pytest collection fails for every test file that transitively imports the module — which poisons the entire Layer 2 validation step. See `references/writing-guide.md` § "Stub Design" for the full rule and examples.

The scaffold is critical because it establishes the testing foundation. Two categories of fixtures belong here — both are things Claude Code can get right that small models consistently fail at:

**Framework collection fixtures:** Autouse fixtures for mocking frameworks not installed in dev (like Airflow). These must work at pytest collection time — not just at test execution time. Small models don't understand the distinction between collection-time and execution-time patching.

**External dependency mock fixtures:** Reusable pytest fixtures for external service clients (Google APIs, boto3/S3, pika/RabbitMQ, database drivers, etc.). These libraries have complex APIs that require precise mock wiring — fluent method chains, buffer-based download loops, connection lifecycle management. Small models consistently fail to mock these correctly, spending all their reflections trying to debug mock plumbing instead of writing business logic. Read `references/tooling.md` § "Creating External Dependency Mock Fixtures" for implementation guidance and examples.

By providing pre-wired fixtures like `mock_drive_service`, `mock_s3_client`, and `mock_pika_connection` in conftest.py, the small model's test code reduces to `def test_download(mock_drive_service):` with simple return-value setup. The tricky mock internals are handled once, correctly, by Claude Code.

After setup, verify both lint and test commands pass (even if no tests exist yet — `pytest` should exit cleanly). Do NOT commit or stage any files — the user manages git operations. Tell the user what you created and suggest they review and commit when ready.

### 3b. Write and Validate Task Tests

For each task in the plan, write its test file now — before generating task documents. The small model's job is to make these tests pass. Claude Code owns test correctness.

Read `references/writing-guide.md` § "Writing Correct Tests" for the full rules. Key requirements:

**Write tests against stubs, then validate with the mutation gate:**

1. Create a minimal stub implementation for each task's module — classes/functions that exist and are importable, but return `None` or raise `NotImplementedError`. This gives the mutation tool something to mutate and satisfies import resolution.
2. Write the test file for the task against the stub.
3. Run the **mutation gate** on the stub + tests. See `references/tooling.md` § "Mutation Testing" for the language-specific tool and commands. Surviving mutants mean weak assertions — strengthen the tests.
4. Run `pytest` against the stub. **Verify that all tests fail, and fail for the right reason:** `NotImplementedError`, assertion failure, or wrong return value — never `ImportError`, `SyntaxError`, or fixture setup errors (those indicate broken test infrastructure, not missing implementation).
5. Once the mutation gate passes and failures are correct, delete the stub bodies (leave empty stubs or `raise NotImplementedError` — do not delete the files, since imports must still resolve).

This two-layer gate — mutation score + correct failure mode — is the mechanical check that tests will actually catch bugs in the small model's implementation.

**Record validation results in the manifest** (Step 6): each task entry gets `"pre_validated": true` and a `"test_file"` field after this step passes. The runner asserts this field before executing a task.

### 4. Extract Project Context

Extract a shared context block from the design doc (10-15 lines max). This gets embedded at the top of every task file so the small model understands the project without needing the full design doc.

Include: what the project does (1-2 sentences), tech stack, key directory structure, lint/test commands, naming conventions, and available conftest fixtures (so the model uses them instead of writing its own mocks). Always end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.` — this prevents small models from outputting conversational text that aider's edit format interprets as filenames.

### 5. Generate Task Documents

For each task in the implementation plan (starting from Phase 2 — Phase 1 scaffold was created in Step 3), generate a standalone markdown file. Read `task-template.md` for the complete template structure.

**Naming:** `NN-task-X.Y-short-description.md` where NN is the zero-padded execution order (starting from 01), X.Y is the original task number, and the description is kebab-case. Since the scaffold is handled in Step 3, task 01 is the first post-scaffold task.

Key principles for task docs:

- **Self-contained.** Inline all relevant context. The model shouldn't need to look at other files or tasks to understand what to do.
- **Explicit file paths** from project root. Never relative, never ambiguous.
- **Interface contracts, not implementation code.** Provide class names, method signatures with type hints, and behavioral specs. Do not include method bodies.

**Tests are pre-written by Claude Code.** Do not include test scenarios as prose — the actual test code is in the `## Tests` section of the task doc (written in Step 3b). The model's job is to implement the code to make the tests pass. Read `task-template.md` for the `## Tests` section format.
- **No prose test scenarios.** Tests are written by Claude Code (Step 3b) and embedded directly in the task doc. Remove the `## Test Scenarios` section from task docs — it is replaced by the `## Tests` section.
- **Environment constraints.** State what's mocked, what's not installed, what can't make real connections. Don't prescribe mock patterns — the model picks patterns it knows work.
- **Wiring steps.** When a task modifies existing files (adding to registries, import maps), state what to add and where. The model handles the mechanics.
- **One commit per task** with a conventional commit message.

**Deferred tasks:** Some tasks depend on the exact interfaces produced by earlier tasks — integration tests are the most common example. These cannot be accurately written upfront because the small model may produce slightly different signatures or parameter names than what the plan specifies. Mark these as `"deferred": true` in the manifest and **do not generate their task doc files yet**. See `references/writing-guide.md` for guidance on identifying which tasks should be deferred.

Read `references/writing-guide.md` for deeper guidance on writing style, splitting large tasks, complexity ratings, deferred task identification, and test correctness rules.

### 6. Generate the Manifest

Create `00-manifest.json` with task metadata and a `tooling` section:

```json
{
  "plan_source": "docs/plans/...-implementation.md",
  "design_source": "docs/plans/...-design.md",
  "generated_at": "2026-01-29T18:00:00Z",
  "total_tasks": 25,
  "tooling": {
    "lint_cmd": "ruff check .",
    "test_cmd": "cd services/airflow-ingestion && python -m pytest -x -q",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  },
  "tasks": [
    {
      "file": "01-task-2.1-pydantic-settings.md",
      "task_id": "2.1",
      "title": "Pydantic Settings",
      "phase": "Core Abstractions",
      "files_created": ["services/airflow-ingestion/config/settings.py",
                         "services/airflow-ingestion/tests/test_settings.py"],
      "files_modified": [],
      "test_command": "cd services/airflow-ingestion && uv run pytest tests/test_settings.py -x -q",
      "test_file": "services/airflow-ingestion/tests/test_settings.py",
      "pre_validated": true,
      "estimated_complexity": "simple"
    },
    {
      "file": "20-task-8.1-pipeline-integration-test.md",
      "task_id": "8.1",
      "title": "Pipeline Integration Tests",
      "phase": "Integration Testing",
      "files_created": ["services/airflow-ingestion/tests/test_pipeline_integration.py"],
      "files_modified": [],
      "test_command": "cd services/airflow-ingestion && uv run pytest tests/test_pipeline_integration.py -x -q",
      "estimated_complexity": "complex",
      "deferred": true,
      "deferred_reason": "Tests real function signatures from all implementation tasks. Must use actual interfaces, not planned ones.",
      "depends_on": ["2.1", "2.2", "3.1", "5.1"]
    }
  ]
}
```

The runner script reads `lint_cmd` and `test_cmd` from the `tooling` section to configure aider's auto-validation flags. Tasks with `"deferred": true` are skipped in the first run — the runner stops before them and prompts for deferred task generation.

### 7. Generate the Runner Script

Copy `scripts/run-tasks-template.sh` verbatim into the output folder as `run-tasks.sh`. Do NOT rewrite it, summarize it, or generate a new script from scratch — the template is the correct, tested implementation.

After copying, make exactly two targeted edits if needed:
- `DEFAULT_MODEL` — update if the project uses a different local model
- `PROJECT_ROOT` path calculation — update if the tasks folder is not 3 levels below the project root (e.g., `../../..`)

The runner:
- Reads lint/test commands from the manifest's `tooling` section
- Passes `--lint-cmd` + `--auto-lint` and `--test-cmd` + `--auto-test` explicitly to aider (regardless of defaults, for clarity)
- Uses `--no-check-update` to prevent aider from self-updating mid-run, and `--yes-always` for non-interactive mode
- Detects deferred tasks from the manifest and stops before executing them, printing instructions to generate deferred task docs and resume
- Captures aider output and detects reflection exhaustion ("reflections allowed, stopping") — marks the task as degraded even if aider exits 0, since aider treats exhausted retries as a graceful exit
- Runs an independent test suite check after each task (not relying solely on aider's exit code) to catch failures aider didn't report
- Halts on non-zero exit or degraded status and prints how to resume with `--start N`
- Supports `--dry-run`, `--model`, and CLI overrides for `--lint-cmd`/`--test-cmd`

### 8. Present Results

Summarize what was generated:

```
Scaffold created and verified (not delegated to task runner):
  - pyproject.toml, conftest.py, __init__.py files, lint config
  - Lint: ruff check . ✓
  - Test: python -m pytest -x -q ✓ (no tests yet — exits cleanly)

Generated 20 task files + 2 deferred + manifest + runner in docs/plans/airflow-google-drive-ingestion-tasks/

Phase breakdown:
  Phase 1: Project Scaffolding    — Claude Code (done above)
  Phase 2: Core Abstractions      — 3 tasks (spec-based)
  Phase 3: Infrastructure Clients — 4 tasks (spec-based)
  ...
  Phase N: Integration Testing    — 2 tasks (deferred)

Deferred tasks (generated after implementation tasks complete):
  22-task-8.1-pipeline-integration-test.md — needs real function signatures from tasks 01-20

To run:
  cd docs/plans/airflow-google-drive-ingestion-tasks
  chmod +x run-tasks.sh
  ./run-tasks.sh --dry-run
  ./run-tasks.sh                 # runs implementation tasks, stops before deferred
  # Generate deferred task docs (Claude Code reads actual code and writes test files)
  ./run-tasks.sh --start 22     # resumes with deferred tasks
```

## Execution Notes

Generate task files sequentially in the main session. Write each file to disk before moving to the next — subagents have permission issues that cause partial output and require manual recovery. Show progress:
```
Creating 01-task-2.1-pydantic-settings.md... ✓
Creating 02-task-2.2-base-record-extractor.md... ✓
```

## Bundled Resources

| Resource | When to read |
|----------|-------------|
| `task-template.md` | When generating task documents (Step 5) — has the complete template with all sections including the `## Tests` section |
| `references/tooling.md` | When determining lint/test commands (Step 2), setting up tooling (Step 3), creating external dependency mock fixtures (Step 3), and running the mutation gate (Step 3b) |
| `references/writing-guide.md` | When writing task doc content and tests — style guidance, test correctness rules, splitting rules, complexity ratings |
| `scripts/lint-ruff-wrapper.sh` | When setting up linting for Python/ruff projects (Step 3) — copy into tasks folder, update `RUFF_BIN`, use as lint_cmd |
| `scripts/run-tasks-template.sh` | When generating the runner script (Step 7) — copy and adapt for the project |
