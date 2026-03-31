---
name: prototype-driven-implementation
description: >
  Generate a LangGraph-based implementation pipeline that executes task
  decomposition output via Aider and local models. Use this skill when the user
  has tasks.json from prototype-driven-task-decomposition and wants to build the
  orchestration pipeline that feeds tasks to Aider. Trigger on phrases like
  "build the pipeline", "generate the implementation pipeline", "create the
  runner", "set up the LangGraph pipeline", or /prototype-implement. Also
  trigger when the user mentions wanting to execute decomposed tasks with Aider,
  local models, or LM Studio and has a tasks.json ready. Do NOT trigger when the
  user wants to run tasks manually, wants to decompose a design doc (that's
  prototype-driven-task-decomposition), or wants to plan a feature (that's
  prototype-driven-planning).
---

# Prototype-Driven Implementation

Generate a LangGraph pipeline that executes decomposed tasks via Aider and local
models. The pipeline reads `tasks.json`, feeds each task to Aider in dependency
order, verifies results with lint and test commands, and tracks pass/fail state
with circuit breakers.

Claude Code generates the pipeline code. The user runs it independently.

## Quick Reference

| Input | Output |
|-------|--------|
| `tasks/<feature>/tasks.json` | `pipelines/<feature>/` — runnable LangGraph pipeline |
| `tasks/<feature>/task_schema.py` | Pipeline is self-contained, runs via `python run.py` |
| `prototypes/<feature>/` | |
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
   - **Lint command**: Check for `ruff.toml`, `pyproject.toml [tool.ruff]`,
     `.flake8`, `setup.cfg [flake8]`, etc. The prototype's lint setup (validated
     during planning) is the ground truth.
   - **Test runner**: Check for `pyproject.toml [tool.pytest]`, `pytest.ini`,
     `jest.config.*`, etc.
   - **Language**: Infer from task file paths and project config.

   The prototype proves these tools work — the pipeline just needs to know
   the commands.

3. **Derive per-task test commands.** For each task that has entries in its
   `tests` field, construct the test command from the `test_file` paths.
   For example, a task with `test_file: "tests/test_client.py"` gets
   `pytest tests/test_client.py -x`. Tasks with no tests get no test gate.

4. **Identify the scaffold bootstrap.** Look at the scaffold-phase tasks.
   If any task creates a project config file (`pyproject.toml`, `package.json`,
   `build.gradle`, etc.), the pipeline must run a tooling bootstrap command
   after that task completes (e.g., `uv sync`, `npm install`, `./gradlew build`).
   Determine the bootstrap command from the project's language and tooling.
   Without this step, lint and test tools won't be available for subsequent tasks.

5. **Check model and Aider availability.** Verify LM Studio is reachable and
   `aider` is on the PATH. Note any missing prerequisites.

**STOP.** Present the analysis:
- Task summary (count by phase and type)
- Detected lint command and test runner
- Bootstrap command and which task triggers it
- Per-task test command derivations (so the user can verify)
- Model endpoint and Aider status
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
   - `config.py` — Model endpoint, retry limits, paths, detected tooling
   - `pipeline_state.py` — LangGraph TypedDict state definition
   - `graph.py` — StateGraph definition with nodes and edges
   - `nodes/__init__.py`
   - `nodes/load_tasks.py` — Reads and validates tasks.json, topological sort
   - `nodes/compose_prompt.py` — Builds Aider message file from task definition
   - `nodes/execute_task.py` — Invokes Aider via subprocess
   - `nodes/verify_task.py` — Independent lint/test verification after Aider
   - `nodes/report.py` — Final summary and results output
   - `aider_bridge.py` — Subprocess wrapper for Aider CLI
   - `requirements.txt` — Dependencies (langgraph, pydantic)
   - `README.md` — How to configure and run

3. **Configure for this project.** The generated `config.py` should contain:
   - The detected lint command (from Phase 1)
   - The detected test runner pattern (from Phase 1)
   - The model endpoint (default: `http://localhost:1234/v1`)
   - The model name (default from LM Studio detection or user input)
   - Paths to `tasks.json`, prototype directory, project root
   - Retry limits (default: 3 per task)
   - The per-task test command map (derived in Phase 1)
   - The scaffold bootstrap config (which task, what command)
   - Per-task working directory assignments

4. **Generate the prompt composer.** The `compose_prompt.py` node turns a task's
   JSON definition into a self-contained markdown message file for Aider. This
   is where prototype references get resolved — read the referenced prototype
   files and inline the relevant sections into the prompt. See
   `references/aider-integration.md` for the prompt template.

**STOP.** Present a summary of generated files and their sizes. Highlight any
decisions made during generation (e.g., "Detected ruff as linter, configured
`ruff check` as lint command"). Wait for user review.

## Phase 3: Validation & Handoff

Read `references/phase-3-handoff.md` for detailed guidance, then:

1. **Syntax check.** Run `python -m py_compile` on all generated `.py` files.
   Fix any syntax errors.

2. **Precondition validation.** Verify the pipeline's configuration is
   consistent: all task IDs in test command maps exist in tasks.json, working
   directory paths are derivable, the service root prefix matches task file
   paths, and the bootstrap command is configured for the right task.

3. **Present run instructions.** Tell the user:
   - How to start LM Studio with the right model
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
  project config files. It doesn't require upstream skills to add new fields
  to their schemas — it reads what's already there.

- **Prototype is the tooling proof.** The planning skill validated that lint
  and tests work. The pipeline reads the same config files and constructs
  commands from them. If the prototype could run `ruff check` and `pytest`,
  the pipeline can too.

- **Tasks are self-contained prompts.** The `compose_prompt.py` node transforms
  each task's JSON into a markdown document that includes everything the
  implementing model needs — description, file paths, inlined prototype
  references, acceptance criteria. Aider receives this as `--message-file`.

- **Graph structure supports extension.** The LangGraph state machine is
  designed so adding escalation tiers (v2) means adding a node and a
  conditional edge, not restructuring the graph.

- **Aider is the executor, not the orchestrator.** Aider runs in scripting
  mode (`--message-file`, `--yes-always`, `--no-git`). The pipeline manages
  state, retries, and verification. Aider just does the coding.

- **Independent verification.** After Aider exits, the pipeline runs lint and
  tests independently. Aider might silently give up (reflection exhaustion) —
  the pipeline catches this.

- **Run without interruption.** The pipeline should be able to execute all
  tasks from start to finish without manual intervention. Scaffold tasks that
  create project config files trigger automatic tooling bootstraps (e.g.,
  `uv sync`, `npm install`). The user should only need to intervene when a
  task exhausts its retries.

- **No dry-run divergence.** The pipeline does not have a `--dry-run` mode.
  A dry-run that skips real execution creates a false sense of validation.
  Phase 3 validates the pipeline through precondition checks and syntax
  verification instead.
