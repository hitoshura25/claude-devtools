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

```
docs/plans/my-service-tasks/
├── 00-manifest.json
├── 01-task-2.1-settings.md
├── ...
├── lint.sh          (primary language lint wrapper, if needed)
├── infra-lint.sh    (infrastructure lint wrapper, if infra tasks present)
├── smoke-test-*.sh  (per-service smoke test scripts, if infra tasks present)
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

Instead: proceed with the full process from Step 1. Generate everything fresh from the current skill files.

### 1. Read and Analyze

Read both the design doc and implementation plan. Build a mental model of total tasks, dependencies between phases, interface contracts, and the project's language/tooling.

**Also scan for infrastructure tasks:** Check whether any task's `files_created` includes `Dockerfile`, `*compose*.yml`, `*.tf`, or Kubernetes YAML. Infrastructure tasks require different tooling than service tasks — flag these now so you can set them up in Step 3.

### 2. Determine Test & Lint Tooling

Identify the primary lint and test commands for the project. These power aider's `--auto-lint` and `--auto-test` flags for all service tasks.

Read `references/tooling.md` for the full discovery process. Then:
- Read the appropriate `references/stacks/<language>-<framework>.md` for the project's primary language
- **If infrastructure tasks were flagged in Step 1**, also read `references/stacks/infra.md` — infrastructure tasks use hadolint, `docker compose config`, and Docker smoke tests instead of language unit tests, and the manifest supports per-task `lint_cmd` overrides for exactly this case

**Every task must have a test.** Service tasks get unit tests; infrastructure tasks get Docker smoke tests (or lint-only for Terraform/k8s). No task should have a null/empty `test_command` unless it genuinely has nothing to validate — and that situation is rare.

### 3. Set Up Tooling and Scaffold (execute directly)

This is the most important step for reliability. Install tooling and create the project scaffold *right now*, directly in the current Claude Code session — do not delegate these to task files for the small model.

Small models can write business logic code, but they can't debug missing tool installations, broken configs, environment issues, or subtle test setup patterns. Claude Code can. By handling setup and scaffold here, every subsequent task starts with a working foundation.

**Tooling setup:** Read `references/tooling.md` and the appropriate stack files. Investigate the project's existing conventions first, then set up tooling consistently with what's already there.

If infrastructure tasks are present:
- Install `hadolint` (see `stacks/infra.md` § "Tooling Setup")
- Copy `scripts/infra-lint-wrapper-template.sh` to the tasks folder as `infra-lint.sh`
- For each Docker/compose task, copy `scripts/docker-smoke-test-template.sh` and configure `COMPOSE_FILE` and `HEALTH_URL`
- Write the self-contained test compose file (see `stacks/infra.md` § "The Two-Compose Pattern")

**Project scaffold:** Create these files directly (see Phase 1 in the implementation plan):
- Build/package config with all dependencies, test config, and lint config
- Test setup file with fixtures
- All package `__init__` files or equivalent for the language
- A stub file for each task (see Step 3b)

**Stub files must not execute code that requires runtime environment.** See `references/writing-guide.md` § "Stub Design" and the stack file for language-specific examples.

After setup, verify both lint and test commands pass. Do NOT commit or stage any files.

### 3b. Write and Validate Task Tests

For each task in the plan, write its test file now — before generating task documents.

Read `references/writing-guide.md` § "Writing Correct Tests" for the full rules. Key requirements:

**For service tasks — write tests against stubs, then validate with the mutation gate:**

1. Create a minimal stub implementation (importable but raises "not implemented")
2. Write the test file against the stub
3. Run the mutation gate — see `references/tooling.md` § "Mutation Testing"
4. Run tests against the stub; verify all fail for the right reason
5. Replace stub bodies with "not implemented" once gates pass

**For infrastructure tasks — validate the smoke test script:**

1. Confirm the smoke test script is configured correctly (`COMPOSE_FILE`, `HEALTH_URL`)
2. Run `bash docs/plans/my-tasks/smoke-test-*.sh` from the project root
3. Confirm it fails appropriately against stubs (build failure or health endpoint timeout)
4. Confirm it succeeds when a working implementation exists

**Record validation results in the manifest** (Step 6): service tasks get `"pre_validated": true` and `"test_file"`. Infrastructure tasks get `"pre_validated": true` (confirming the smoke test script is wired correctly) but no `"test_file"`.

### 4. Extract Project Context

Extract a shared context block from the design doc (10-15 lines max). Embed at the top of every task file. Include: what the project does, tech stack, key directory structure, lint/test commands, naming conventions, and available test fixtures. Always end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.`

### 5. Generate Task Documents

For each task in the implementation plan (starting from Phase 2), generate a standalone markdown file. Read `task-template.md` for the complete template structure.

**Naming:** `NN-task-X.Y-short-description.md`

Key principles:
- **Self-contained.** Inline all relevant context.
- **Explicit file paths** from project root.
- **Interface contracts, not implementation code** (for service tasks).
- **Tests are pre-written by Claude Code** — embed the test file verbatim in `## Tests`.
- **Component tasks create files only — never modify shared files.** See `references/writing-guide.md` § "Task Scope".
- **Infrastructure tasks:** The model creates Dockerfiles and compose files. Claude Code has already written the smoke test script. The task doc tells the model what files to create and what behaviour to implement; it does not embed the smoke test script.

**Deferred vs service-gated:** See `references/writing-guide.md` § "Deferred Tasks vs Service-Gated Tasks".

### 6. Generate the Manifest

Create `00-manifest.json`. The `tooling` block holds the global defaults. Tasks can override `lint_cmd` individually — infrastructure tasks always should.

```json
{
  "plan_source": "docs/plans/...-implementation.md",
  "design_source": "docs/plans/...-design.md",
  "generated_at": "2026-01-29T18:00:00Z",
  "total_tasks": 20,
  "tooling": {
    "lint_cmd": "./docs/plans/my-tasks/lint.sh",
    "test_cmd": "cd services/my-service && uv run pytest tests/ -x -q --ignore=tests/test_integration.py",
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
      "file": "18-task-7.1-docker-deployment.md",
      "task_id": "7.1",
      "title": "Docker Deployment",
      "phase": "Deployment",
      "files_created": [
        "services/my-service/Dockerfile",
        "services/my-service/deployment/service.compose.yml",
        "services/my-service/deployment/service.test.compose.yml"
      ],
      "files_modified": [],
      "lint_cmd": "docs/plans/my-tasks/infra-lint.sh",
      "test_command": "bash docs/plans/my-tasks/smoke-test-my-service.sh",
      "pre_validated": true,
      "estimated_complexity": "moderate",
      "depends_on": ["6.1"]
    },
    {
      "file": "19-task-8.1-integration-tests.md",
      "task_id": "8.1",
      "title": "Integration Tests",
      "phase": "Integration Testing",
      "files_created": ["services/my-service/tests/test_integration.py"],
      "files_modified": [],
      "test_command": "cd services/my-service && uv run pytest tests/test_integration.py -x -q",
      "test_file": "services/my-service/tests/test_integration.py",
      "pre_validated": true,
      "estimated_complexity": "complex",
      "deferred": false,
      "requires_services": ["minio", "rabbitmq"],
      "service_check_commands": {
        "minio": "curl -sf http://localhost:9000/minio/health/live",
        "rabbitmq": "curl -sf http://localhost:15672/api/overview -u guest:guest"
      },
      "depends_on": ["7.1"]
    }
  ]
}
```

Note: `requires_services` is now a hard requirement — the runner exits if services are unavailable, rather than skipping. Start services before running tasks that need them.

### 7. Generate the Runner Script

Copy `scripts/run-tasks-template.sh` verbatim into the output folder as `run-tasks.sh`. Do NOT rewrite it — the template is the correct, tested implementation.

**Do not restore `run-tasks.sh` from git history.** Always copy from `scripts/run-tasks-template.sh`.

After copying, make exactly two targeted edits if needed:
- `DEFAULT_MODEL` — update if the project uses a different local model
- `PROJECT_ROOT` path calculation — update if the tasks folder is not 3 levels below the project root

### 8. Present Results

Summarize what was generated: scaffold created, N task files, M infrastructure tasks with smoke tests, manifest, runner. Include the phase breakdown and the commands to run.

## Execution Notes

Generate task files sequentially in the main session. Write each file to disk before moving to the next. Show progress as you go.

## Bundled Resources

| Resource | When to read |
|----------|-------------|
| `task-template.md` | Step 5 — complete template with all sections |
| `references/tooling.md` | Steps 2, 3, 3b — tooling discovery, fixture criteria, mutation gate, mixed-technology projects |
| `references/stacks/<language>-<framework>.md` | Steps 2, 3, 3b — language-specific install, lint wrapper, fixtures, stubs, mutation tool |
| `references/stacks/infra.md` | Steps 2, 3, 3b — when any task creates Dockerfile/compose/Terraform/k8s files |
| `references/writing-guide.md` | Steps 3b, 5 — test correctness, stub design, task scope, deferred/service-gated guidance |
| `scripts/lint-ruff-wrapper.sh` | Step 3, Python/ruff — copy to tasks folder, update `RUFF_BIN` |
| `scripts/infra-lint-wrapper-template.sh` | Step 3, infra tasks — copy to tasks folder as `infra-lint.sh`, set `RUFF_BIN` if needed |
| `scripts/docker-smoke-test-template.sh` | Step 3b, Docker tasks — copy per service, set `COMPOSE_FILE` and `HEALTH_URL` |
| `scripts/run-tasks-template.sh` | Step 7 — copy verbatim, make two targeted edits |
