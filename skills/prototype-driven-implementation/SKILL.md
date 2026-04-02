---
name: prototype-driven-implementation
description: >
  Generate a LangGraph-based implementation pipeline that executes task
  decomposition output via configurable coding agent executors (Aider, Claude
  CLI, Gemini CLI). Use this skill when the user has tasks.json from
  prototype-driven-task-decomposition and wants to build the orchestration
  pipeline that feeds tasks to coding agents. Trigger on phrases like "build the
  pipeline", "generate the implementation pipeline", "create the runner", "set
  up the LangGraph pipeline", or /prototype-implement. Also trigger when the
  user mentions wanting to execute decomposed tasks with Aider, Claude Code,
  Gemini CLI, local models, or LM Studio and has a tasks.json ready. Do NOT
  trigger when the user wants to run tasks manually, wants to decompose a design
  doc (that's prototype-driven-task-decomposition), or wants to plan a feature
  (that's prototype-driven-planning).
---

# Prototype-Driven Implementation

Generate a LangGraph pipeline that executes decomposed tasks via configurable
coding agent executors. The pipeline reads `tasks.json`, dispatches each task
to the appropriate executor (Aider, Claude CLI, or Gemini CLI) based on role
assignments, auto-fixes trivially fixable lint errors, verifies results with
independent lint and test checks, and escalates to stronger executors when
weaker ones exhaust their retries.

Claude Code generates the pipeline code. The user runs it independently.

## Quick Reference

| Input | Output |
|-------|--------|
| `tasks/<feature>/tasks.json` | `pipelines/<feature>/` — runnable LangGraph pipeline |
| `tasks/<feature>/task_schema.py` | Pipeline is self-contained, runs via `python run.py` |
| `prototypes/<feature>/` | |
| `docs/design/<feature>.md` | Tooling section read for auto-fix detection |
| Project config files (`pyproject.toml`, etc.) | |

## How to Start

The feature name comes from `$ARGUMENTS`. If `$ARGUMENTS` is empty, check for
`tasks/` subdirectories containing `tasks.json` and ask which feature to build
the pipeline for.

Confirm that these exist before proceeding:
- `tasks/<feature>/tasks.json` — the decomposed tasks
- `tasks/<feature>/task_schema.py` — the validation schema
- `prototypes/<feature>/` — the prototype directory

If any are missing, stop and explain which upstream skill needs to run first.

Announce: "I'm using the prototype-driven-implementation skill to generate the
LangGraph pipeline for executing the decomposed tasks."

## Phase 1: Pipeline Analysis

Read `references/phase-1-analysis.md` for detailed guidance, then:

1. **Validate the task decomposition.** Load `tasks.json` and validate it
   against `task_schema.py`. Report the task count, dependency depth, and
   phase breakdown. If validation fails, stop — the decomposition needs fixing.

2. **Detect tooling commands.** Look at the project's configuration to determine:
   - **Lint command**: Check the design doc's Tooling section first, then fall
     back to detecting from `ruff.toml`, `pyproject.toml [tool.ruff]`, etc.
   - **Lint auto-fix command**: Check the design doc's Tooling section. If
     not present, detect manually from the ecosystem (e.g., `ruff check --fix`).
     Verify the auto-fix command works against a prototype file.
   - **Test runner**: Check for `pyproject.toml [tool.pytest]`, `pytest.ini`,
     `jest.config.*`, etc.
   - **Language**: Infer from task file paths and project config.

3. **Derive per-task test commands.** For each task that has entries in its
   `tests` field, construct the test command from the `test_file` paths.
   Tasks with no tests get no test gate.

4. **Identify the scaffold bootstrap.** Look at the scaffold-phase tasks.
   If any task creates a project config file, determine the bootstrap command
   from the project's language and tooling.

5. **Detect available executors and propose role assignments.** Check what
   coding agent CLIs are available and what models they can access:
   - Check `aider --version` — if available, check LM Studio for local models
     and note any API keys set for cloud model backends
   - Check `claude --version` — if available, note it uses Pro plan auth
     (no API key needed)
   - Check `gemini --version` — if available, note auth method (Google
     account or GEMINI_API_KEY)

   Present the detected executors and propose assignments for three roles:
   - `test` — benefits from a strong executor (writes real assertions, not stubs)
   - `implementation` — local executor first, with optional escalation
   - `scaffold` — any capable executor, no escalation needed

   Each role maps to an ordered list of executor names (the escalation chain).

6. **Verify executor availability.** For each executor that appears in any
   role, verify it can actually run: CLI is on PATH, required auth is set,
   local model server is reachable (for Aider+LM Studio).

**STOP.** Present the analysis:
- Task summary (count by phase and type)
- Detected lint command, auto-fix command, and test runner
- Bootstrap command and which task triggers it
- Per-task test command derivations (so the user can verify)
- Executor configuration with role assignments (for user confirmation)
- Any issues or ambiguities

Wait for user confirmation before proceeding to Phase 2.

## Phase 2: Pipeline Generation

Read `references/phase-2-generation.md` for detailed guidance, then:

1. **Create `pipelines/<feature-name>/`.** This is the pipeline's home directory.

2. **Generate the pipeline files.** Create each file in the pipeline directory.
   Read `references/langgraph-patterns.md` for the state machine design and
   `references/executor-integration.md` for how to invoke each executor type.

   The files to generate:
   - `run.py` — Entry point with CLI arguments (`--start`, `--executor`)
   - `config.py` — Executors, role assignments, retry limits, paths, tooling
   - `pipeline_state.py` — LangGraph TypedDict state definition
   - `graph.py` — StateGraph definition with nodes and edges
   - `nodes/__init__.py`
   - `nodes/load_tasks.py` — Reads and validates tasks.json, topological sort
   - `nodes/compose_prompt.py` — Builds prompt content from task definition
   - `nodes/execute_task.py` — Dispatches to the appropriate executor
   - `nodes/verify_task.py` — Auto-fix + independent lint/test verification
   - `nodes/report.py` — Final summary and results output
   - `agent_bridge.py` — Executor dispatch and subprocess wrappers
   - `requirements.txt` — Dependencies (langgraph, pydantic)
   - `README.md` — How to configure and run

3. **Configure for this project.** The generated `config.py` should contain:
   - `EXECUTORS` dict — each named executor with its type and type-specific
     params (Aider executors include model string and API config; Claude and
     Gemini executors include optional model selection)
   - `EXECUTOR_ROLES` dict — user-confirmed role → executor name list mappings
   - The detected lint command and lint auto-fix command
   - Paths to `tasks.json`, prototype directory, project root
   - Retry limits (default: 3 per task per executor tier)
   - The per-task test command map (derived in Phase 1)
   - The scaffold bootstrap config (which task, what command)
   - Per-task working directory assignments
   - Startup validation (`_validate_executors()`) that fails fast if a
     required executor's CLI is not available or its auth is not configured

4. **Generate the prompt composer.** The `compose_prompt.py` node turns a task's
   JSON definition into a self-contained markdown prompt. This is where
   prototype references get resolved — read the referenced prototype files and
   inline the relevant sections. Additionally:
   - **Inline dependency interfaces** — for each dependency task, read the
     current content of files it created and include the public interface
     (class names, method signatures, import paths) so the implementing model
     writes correct imports and call sites.
   - **Include import conventions** — state the project's import convention
     in the project context block of every prompt.
   - **Test-task guidance** — for test-type tasks, include explicit rules
     against `NotImplementedError` stubs in test bodies.
   - **Retry/escalation context** — on retries, include error output from
     the previous attempt. On escalation, include context about the previous
     executor's failure.

**STOP.** Present a summary of generated files and their sizes. Highlight any
decisions made during generation. Wait for user review.

## Phase 3: Validation & Handoff

Read `references/phase-3-handoff.md` for detailed guidance, then:

1. **Syntax check.** Run `python -m py_compile` on all generated `.py` files.
   Fix any syntax errors.

2. **Precondition validation.** Verify the pipeline's configuration is
   consistent: all task IDs in test command maps exist in tasks.json, working
   directory paths are derivable, the service root prefix matches task file
   paths, the bootstrap command is configured for the right task, all executor
   names referenced in `EXECUTOR_ROLES` exist in `EXECUTORS`, and required
   CLIs and auth are available for all active executors.

3. **Present run instructions.** Tell the user:
   - Which executors need to be running (e.g., start LM Studio for Aider
     executors)
   - Which environment variables to set (if any)
   - How to install dependencies (`pip install -r requirements.txt`)
   - How to run the pipeline (`python run.py`)
   - How to resume from a specific task (`python run.py --start task-05`)
   - Where logs and results are stored

**STOP.** Present the handoff. The user takes over from here — they run the
pipeline, review results, and iterate as needed.

## Principles

- **Generate, don't execute.** Claude Code builds the pipeline; the user runs
  it. The pipeline is a standalone Python project with no dependency on Claude
  Code or the devtools directory.

- **Derive, don't require.** The pipeline figures out lint/test commands from
  project config files and the design doc's Tooling section.

- **Prototype is the tooling proof.** The planning skill validated that lint
  and tests work. The pipeline reads the same config files and constructs
  commands from them.

- **Tasks are self-contained prompts.** The `compose_prompt.py` node transforms
  each task's JSON into a markdown document with everything the coding agent
  needs. Different executors receive the prompt in their own format.

- **Executors are coding agents, not models.** An executor is a CLI tool that
  can read files, write code, and iterate (Aider, Claude CLI, Gemini CLI).
  Each executor type has its own invocation conventions. A model is just a
  parameter of certain executors. `EXECUTORS` defines each named executor
  with its type and config; `EXECUTOR_ROLES` assigns them to task roles.

- **Right executor for the right job.** Test-writing tasks benefit from strong
  executors that produce real assertions. Implementation tasks work well with
  local executors constrained by pre-written tests. Role assignments are
  user-confirmed, not hardcoded.

- **Auto-fix before judgment.** After the executor exits, the pipeline runs
  the linter's auto-fix command to resolve trivially fixable errors. The lint
  check runs after auto-fix.

- **Escalate, don't give up.** When an executor exhausts its retries, the
  pipeline escalates to the next executor in the role's chain before marking
  the task as failed.

- **Fail fast on configuration.** CLI availability, auth, and tooling commands
  are validated at pipeline startup.

- **Independent verification.** After the executor exits, the pipeline runs
  lint and tests independently. Executors might silently give up — the
  pipeline catches this.

- **Run without interruption.** The pipeline should execute all tasks from
  start to finish without manual intervention. Scaffold tasks trigger
  automatic bootstraps. The user should only need to intervene when a task
  exhausts all executor tiers.

- **No dry-run divergence.** The pipeline does not have a `--dry-run` mode.
  Phase 3 validates through precondition checks and syntax verification instead.
