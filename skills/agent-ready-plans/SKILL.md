---
name: agent-ready-plans
description: Decompose implementation plans into individual task files for smaller AI coding agents like aider running local models (Qwen Coder, Codestral) via LMStudio. Use this skill whenever someone says "decompose this plan", "break this into aider tasks", "create task files for local agents", "make this plan agent-ready", or wants to delegate implementation to smaller models. Also trigger when a user has a design doc + implementation plan and mentions aider, LMStudio, local models, or task decomposition — even if they don't explicitly say "agent-ready".
---

# Agent-Ready Plans

Translate a design document + implementation plan into self-contained task files that smaller AI coding agents can execute sequentially. Each task is an aider `--message-file` with everything a small model needs: context, instructions, complete code, and verification via auto-lint and auto-test.

The key insight: Claude is great at architecture and planning, but the actual line-by-line code generation can be delegated to cheaper local models. This skill bridges that gap — it produces task files that don't require deep reasoning, just the ability to follow precise instructions.

Announce at start: "I'm using the agent-ready-plans skill to break this plan into individual task files."

## Inputs

1. **Design document** — the "what and why" (architecture, data model, decisions)
2. **Implementation plan** — the "how" (phased tasks with TDD steps, file paths, code)

Both are typically markdown files in `docs/plans/`.

## Output

A subfolder next to the plan file, named after the plan (strip the date prefix and `-implementation` suffix).

Example: `docs/plans/2026-01-29-airflow-google-drive-ingestion-implementation.md` produces:

```
docs/plans/airflow-google-drive-ingestion-tasks/
├── 00-manifest.json
├── 01-task-1.1-create-service-directory.md
├── 02-task-1.2-create-requirements-file.md
├── ...
└── run-tasks.sh
```

Each plan gets its own uniquely-named folder — reusing a generic `tasks/` directory causes collisions when decomposing multiple plans.

## Process

### 1. Read and Analyze

Read both the design doc and implementation plan. Build a mental model of total tasks, dependencies between phases, which tasks have full code vs. stubs, and the project's language/tooling.

### 2. Determine Test & Lint Tooling

Identify the lint and test commands for the project. These power aider's `--auto-lint` and `--auto-test` flags, which automatically validate every task's output — this is how errors get caught.

Read `references/tooling.md` for common commands by language and the manifest format.

### 3. Set Up Test & Lint Tooling (execute directly)

This is the most important step for reliability. Install and configure the test framework and linter *right now*, directly in the current Claude Code session — do not delegate this to a task file for the small model.

Small models can write code that passes lint and tests, but they can't debug missing tool installations, broken configs, or environment issues. Claude Code can. By handling setup here, every subsequent task starts with working tooling.

Read `references/tooling.md` for the full discovery and setup process. The key idea: investigate the project's existing conventions first (package manager, virtual environment, monorepo structure), then set up tooling in a way that's consistent with what's already there. If the project uses uv, use uv. If it uses poetry, use poetry. If there's no existing convention, ask the user.

Three things to get right during setup (all covered in `references/tooling.md`):
- **Install project dependencies**, not just lint/test tools. Tests will fail with `ModuleNotFoundError` if only ruff and pytest are installed but the project's libraries are missing.
- **Use the lint wrapper script** (`scripts/lint-ruff-wrapper.sh` for Python/ruff projects). Aider appends every edited filename to the lint command, including non-Python files like `requirements.txt` that ruff can't parse. The wrapper filters to `.py` files only and runs ruff with `--fix` so trivial issues (import sorting, unused imports) are auto-corrected.
- **Avoid `cd` in the lint command.** Aider appends file paths relative to the project root, which break after a directory change. The wrapper handles this. Test commands can use `cd` since aider runs them as-is.

After setup, verify both commands pass, commit the result, and tell the user what you did.

### 4. Extract Project Context

Extract a shared context block from the design doc (10-15 lines max). This gets embedded at the top of every task file so the small model understands the project without needing the full design doc.

Include: what the project does (1-2 sentences), tech stack, key directory structure, lint/test commands, naming conventions. Always end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.` — this prevents small models from outputting conversational text that aider's edit format interprets as filenames.

### 5. Generate Task Documents

For each task in the implementation plan, generate a standalone markdown file. Read `task-template.md` for the complete template structure.

**Naming:** `NN-task-X.Y-short-description.md` where NN is the zero-padded execution order (starting from 01), X.Y is the original task number, and the description is kebab-case.

Key principles for task docs — these matter because small models can't infer what you mean, they need everything spelled out:

- **Self-contained.** Inline all relevant context. The model shouldn't need to look at other files or tasks to understand what to do.
- **Explicit file paths** from project root. Never relative, never ambiguous.
- **Complete code.** Provide the full implementation body, not "add validation logic here." Small models struggle with underspecified instructions.
- **Test-first ordering.** When a task has TDD steps, test file content comes before implementation.
- **Every task must include tests** that pass when correctly implemented. If the plan doesn't specify tests for a task, write them. Auto-test means aider will run tests after each edit and try to fix failures.
- **Code must be lint-clean.** Auto-lint means aider will lint after each edit. Violations in the task doc create unnecessary fix loops.
- **One commit per task** with a conventional commit message.

**Deferred tasks:** Some tasks depend on the exact interfaces produced by earlier tasks — integration tests are the most common example. These cannot be accurately written upfront because the small model may produce slightly different signatures, return types, or parameter names than what the plan specifies. Mark these as `"deferred": true` in the manifest and **do not generate their task doc files yet**. Instead, create a placeholder entry in the manifest describing what the deferred task should test/do. See `references/writing-guide.md` for guidance on identifying which tasks should be deferred.

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
    "lint_cmd": "ruff check .",
    "test_cmd": "cd services/airflow-ingestion && python -m pytest -x -q",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  },
  "tasks": [
    {
      "file": "01-task-1.1-create-service-directory.md",
      "task_id": "1.1",
      "title": "Create Service Directory Structure",
      "phase": "Project Scaffolding",
      "files_created": ["..."],
      "files_modified": [],
      "test_command": null,
      "estimated_complexity": "simple"
    },
    {
      "file": "25-task-12.1-dag-integration-test.md",
      "task_id": "12.1",
      "title": "DAG Integration Tests",
      "phase": "Integration Testing",
      "files_created": ["services/airflow-ingestion/tests/test_dag_integration.py"],
      "files_modified": [],
      "test_command": null,
      "estimated_complexity": "complex",
      "deferred": true,
      "deferred_reason": "Tests real function signatures produced by tasks 8-24. Must be generated after implementation tasks complete.",
      "depends_on": ["8.1", "9.1", "10.1"]
    }
  ]
}
```

The runner script reads `lint_cmd` and `test_cmd` from the `tooling` section to configure aider's auto-validation flags. Tasks with `"deferred": true` are skipped in the first run — the runner stops before them and prompts for deferred task generation.

### 7. Generate the Runner Script

Copy the runner template from `scripts/run-tasks-template.sh` into the output folder as `run-tasks.sh`. Update the `DEFAULT_MODEL` and `PROJECT_ROOT` path calculation if the project structure differs from the default.

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
Generated 23 task files + 2 deferred + manifest + runner in docs/plans/airflow-google-drive-ingestion-tasks/

Tooling (installed and verified):
  Lint: ruff check . (--auto-lint enabled)
  Test: python -m pytest -x -q (--auto-test enabled)

Phase breakdown:
  Phase 1: Project Scaffolding    — 3 tasks (simple)
  Phase 2: Google Drive Client    — 1 task (moderate)
  ...
  Phase 6: Integration Testing    — 2 tasks (complex, deferred)

Deferred tasks (generated after implementation tasks complete):
  25-task-12.1-dag-integration-test.md — needs real function signatures from tasks 8-24

To run:
  cd docs/plans/airflow-google-drive-ingestion-tasks
  chmod +x run-tasks.sh
  ./run-tasks.sh --dry-run
  ./run-tasks.sh                 # runs implementation tasks, stops before deferred
  # Generate deferred task docs (Claude Code reads actual code and writes test files)
  ./run-tasks.sh --start 25     # resumes with deferred tasks
```

## Execution Notes

Generate task files sequentially in the main session. Write each file to disk before moving to the next — subagents have permission issues that cause partial output and require manual recovery. Show progress:
```
Creating 01-task-1.1-create-service-directory.md... ✓
Creating 02-task-1.2-create-requirements-file.md... ✓
```

## Bundled Resources

| Resource | When to read |
|----------|-------------|
| `task-template.md` | When generating task documents (Step 5) — has the complete template with all sections |
| `references/tooling.md` | When determining lint/test commands (Step 2) and setting up tooling (Step 3) |
| `references/writing-guide.md` | When writing task doc content — style guidance, splitting rules, complexity ratings |
| `scripts/lint-ruff-wrapper.sh` | When setting up linting for Python/ruff projects (Step 3) — copy into tasks folder, update `RUFF_BIN`, use as lint_cmd |
| `scripts/run-tasks-template.sh` | When generating the runner script (Step 7) — copy and adapt for the project |
