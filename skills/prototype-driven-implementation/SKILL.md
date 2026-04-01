---
name: prototype-driven-implementation
description: >
  Generate a LangGraph-based implementation pipeline that executes task
  decomposition output via Aider and configurable models. Use this skill when
  the user has tasks.json from prototype-driven-task-decomposition and wants to
  build the orchestration pipeline that feeds tasks to Aider. Trigger on phrases
  like "build the pipeline", "generate the implementation pipeline", "create the
  runner", "set up the LangGraph pipeline", or /prototype-implement. Also
  trigger when the user mentions wanting to execute decomposed tasks with Aider,
  local models, or LM Studio and has a tasks.json ready. Do NOT trigger when the
  user wants to run tasks manually, wants to decompose a design doc (that's
  prototype-driven-task-decomposition), or wants to plan a feature (that's
  prototype-driven-planning).
---

# Prototype-Driven Implementation

Generate a LangGraph pipeline that executes decomposed tasks via Aider with
configurable models per role. The pipeline reads `tasks.json`, feeds each task
to Aider in dependency order, auto-fixes trivially fixable lint errors, verifies
results with independent lint and test checks, and escalates to stronger models
when weaker ones exhaust their retries.

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

5. **Detect available models and propose role assignments.** Check LM Studio
   for local models and environment variables for cloud API keys. Present
   the detected models and propose assignments for three roles:
   - `test` — benefits from a strong model (writes real assertions, not stubs)
   - `implementation` — local model first, with optional cloud escalation
   - `scaffold` — local model, no escalation needed

   Each role maps to an ordered list of models (the escalation chain).

6. **Check Aider availability.** Verify `aider` is on the PATH.

**STOP.** Present the analysis:
- Task summary (count by phase and type)
- Detected lint command, auto-fix command, and test runner
- Bootstrap command and which task triggers it
- Per-task test command derivations (so the user can verify)
- Model configuration with role assignments (for user confirmation)
- Any issues or ambiguities

Wait for user confirmation before proceeding to Phase 2.

## Phase 2: Pipeline Generation

Read `references/phase-2-generation.md` for detailed guidance, then:

1. **Create `pipelines/<feature-name>/`.** This is the pipeline's home directory.

2. **Generate the pipeline files.** Create each file in the pipeline directory.
   Read `references/langgraph-patterns.md` for the state machine design and
   `references/aider-integration.md` for how to invoke Aider.

   The files to generate:
   - `run.py` — Entry point with CLI arguments (`--start`, `--model`)
   - `config.py` — Models, role assignments, retry limits, paths, tooling
   - `pipeline_state.py` — LangGraph TypedDict state definition
   - `graph.py` — StateGraph definition with nodes and edges
   - `nodes/__init__.py`
   - `nodes/load_tasks.py` — Reads and validates tasks.json, topological sort
   - `nodes/compose_prompt.py` — Builds Aider message file from task definition
   - `nodes/execute_task.py` — Invokes Aider via subprocess
   - `nodes/verify_task.py` — Auto-fix + independent lint/test verification
   - `nodes/report.py` — Final summary and results output
   - `aider_bridge.py` — Subprocess wrapper for Aider CLI
   - `requirements.txt` — Dependencies (langgraph, pydantic)
   - `README.md` — How to configure and run

3. **Configure for this project.** The generated `config.py` should contain:
   - `MODELS` dict — each model defined once with connection params
   - `MODEL_ROLES` dict — user-confirmed role → model list mappings
   - The detected lint command and lint auto-fix command
   - Paths to `tasks.json`, prototype directory, project root
   - Retry limits (default: 3 per task per model tier)
   - The per-task test command map (derived in Phase 1)
   - The scaffold bootstrap config (which task, what command)
   - Per-task working directory assignments
   - Startup validation (`_resolve_api_keys()`) that fails fast if a
     required cloud model's API key environment variable is not set

4. **Generate the prompt composer.** The `compose_prompt.py` node turns a task's
   JSON definition into a self-contained markdown message file for Aider. This
   is where prototype references get resolved — read the referenced prototype
   files and inline the relevant sections into the prompt. Additionally:
   - **Inline dependency interfaces** — for each dependency task, read the
     current content of files it created and include the public interface
     (class names, method signatures, import paths) so the implementing model
     writes correct imports and call sites.
   - **Include import conventions** — state the project's import convention
     (e.g., `from plugins.*` not `from services.*`) in the project context
     block of every prompt.
   - **Test-task guidance** — for test-type tasks, include explicit rules
     against `NotImplementedError` stubs in test bodies. Tests must contain
     real assertions.
   - **Retry/escalation context** — on retries, include error output from
     the previous attempt. On escalation, include context about the weaker
     model's failure.

**STOP.** Present a summary of generated files and their sizes. Highlight any
decisions made during generation. Wait for user review.

## Phase 3: Validation & Handoff

Read `references/phase-3-handoff.md` for detailed guidance, then:

1. **Syntax check.** Run `python -m py_compile` on all generated `.py` files.
   Fix any syntax errors.

2. **Precondition validation.** Verify the pipeline's configuration is
   consistent: all task IDs in test command maps exist in tasks.json, working
   directory paths are derivable, the service root prefix matches task file
   paths, the bootstrap command is configured for the right task, all models
   referenced in `MODEL_ROLES` exist in `MODELS`, and API key environment
   variables are set for cloud models that appear in active roles.

3. **Present run instructions.** Tell the user:
   - How to start LM Studio with the right model
   - Which environment variables to set (for cloud models)
   - How to install dependencies (`pip install -r requirements.txt`)
   - How to run the pipeline (`python run.py`)
   - How to resume from a specific task (`python run.py --start task-05`)
   - How to use a different model (`python run.py --model <model-string>`)
   - Where logs and results are stored

**STOP.** Present the handoff. The user takes over from here — they run the
pipeline, review results, and iterate as needed.

## Principles

- **Generate, don't execute.** Claude Code builds the pipeline; the user runs
  it. The pipeline is a standalone Python project with no dependency on Claude
  Code or the devtools directory.

- **Derive, don't require.** The pipeline figures out lint/test commands from
  project config files and the design doc's Tooling section. It doesn't require
  upstream skills to add new fields to their schemas — it reads what's already
  there.

- **Prototype is the tooling proof.** The planning skill validated that lint
  and tests work. The pipeline reads the same config files and constructs
  commands from them.

- **Tasks are self-contained prompts.** The `compose_prompt.py` node transforms
  each task's JSON into a markdown document that includes everything the
  implementing model needs — description, file paths, inlined prototype
  references, dependency interfaces, acceptance criteria. Aider receives this
  as `--message-file`.

- **Right model for the right job.** Test-writing tasks benefit from strong
  models that produce real assertions. Implementation tasks work well with
  local models constrained by pre-written tests. The `MODEL_ROLES` config
  makes this assignment explicit and user-confirmed.

- **Auto-fix before judgment.** After Aider exits, the pipeline runs the
  linter's auto-fix command to resolve trivially fixable errors (import
  sorting, unused imports). This prevents models from wasting reflection
  cycles on mechanically fixable problems. The lint check runs after auto-fix.

- **Escalate, don't give up.** When a model exhausts its retries, the pipeline
  escalates to the next model in the role's escalation chain before marking
  the task as failed. Only tasks that exhaust all tiers are marked failed.

- **Fail fast on configuration.** API keys, model availability, and tooling
  commands are validated at pipeline startup. A missing `ANTHROPIC_API_KEY`
  produces a clear error at launch, not a cryptic failure 20 tasks in.

- **Aider is the executor, not the orchestrator.** Aider runs in scripting
  mode (`--message-file`, `--yes-always`, `--no-git`). The pipeline manages
  state, retries, escalation, and verification. Aider just does the coding.

- **Independent verification.** After Aider exits, the pipeline runs lint and
  tests independently. Aider might silently give up (reflection exhaustion) —
  the pipeline catches this.

- **Run without interruption.** The pipeline should execute all tasks from
  start to finish without manual intervention. Scaffold tasks trigger
  automatic bootstraps. The user should only need to intervene when a task
  exhausts all model tiers.

- **No dry-run divergence.** The pipeline does not have a `--dry-run` mode.
  Phase 3 validates through precondition checks and syntax verification instead.
