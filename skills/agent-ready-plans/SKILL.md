---
name: agent-ready-plans
description: Package validated implementation plans into individual task files for smaller AI coding agents like aider running local models (Qwen Coder, Codestral) via LMStudio. Use this skill whenever someone says "decompose this plan", "break this into aider tasks", "create task files for local agents", "make this plan agent-ready", or wants to delegate implementation to smaller models. Also trigger when a user has a validated plan with stubs and tests on disk and mentions aider, LMStudio, local models, or task decomposition — even if they don't explicitly say "agent-ready". This skill reads validated artifacts from disk (stubs, tests, lint scripts) and generates task documents, manifest, and runner. Use devtools:implementation-planning first to produce the validated scaffold.
---

# Agent-Ready Plans

Package a validated implementation plan into self-contained task files that smaller AI coding agents can execute sequentially. Each task is an aider `--message-file` with an interface contract, behavioral specs, and a reference to pre-written tests — everything a small model needs to implement and test one component.

**Prerequisite:** The `devtools:implementation-planning` skill must have run first. It produces the design doc, implementation plan, AND validated scaffold (stubs, tests, conftest, lint scripts, Dockerfile) on disk. This skill reads those artifacts directly — it does not interpret plan prose for code-level details.

Announce at start: "I'm using the agent-ready-plans skill to package the validated plan into individual task files."

## Inputs

1. **Design document** — the "what and why" (architecture, data model, decisions)
2. **Implementation plan** — the "how" (phased tasks with behavioral intent, test scenarios, and wiring steps)
3. **Validated scaffold on disk** — stubs, tests, conftest, lint scripts, Dockerfile, smoke test scripts (all produced and verified by implementation-planning)

Both documents are typically markdown files in `docs/plans/`. The scaffold is in the project's source tree.

## Output

A subfolder next to the plan file, named after the plan (strip the date prefix and `-implementation` suffix).

```
docs/plans/my-service-tasks/
├── 00-manifest.json
├── 01-task-2.1-settings.md
├── ...
└── run-tasks.sh
```

Task numbering starts at Phase 2 because Phase 1 (scaffold) was created by implementation-planning.

## Process

### 0. Check for Stale Git Artifacts — Do This First

Check whether output files from a previous run exist in git history:

```bash
git ls-tree -r HEAD --name-only | grep "docs/plans/.*-tasks/"
```

If previous files appear in HEAD, **do not restore them with `git checkout HEAD`**. Those files are stale — the user deleted them to trigger a fresh regeneration. Proceed with the full process from Step 1.

### 1. Read and Analyze

Read both the design doc and implementation plan. Build a mental model of total tasks, dependencies, and the project's language/tooling.

**Verify scaffold exists:** Check that stubs, tests, conftest, and lint scripts are on disk. If they're missing, stop and tell the user to run `devtools:implementation-planning` first.

### 2. Extract Project Context

Extract a shared context block from the design doc (10-15 lines max). Include: what the project does, tech stack, directory structure, lint/test commands, conventions, available fixtures. Always end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.`

### 3. Generate Task Documents

For each task (starting from Phase 2), generate a standalone markdown file. Read `task-template.md` for the complete template.

**Naming:** `NN-task-X.Y-short-description.md`

**All code-level content comes from on-disk files, not plan prose.** Before writing each task doc:
1. Read the **stub file on disk** for the interface contract
2. Read the **test file on disk** for behavioral expectations
3. The plan provides decomposition intent and phasing — the stub and test files are the ground truth

**Interface Contract code blocks are copied from the stub.** The stub was validated against the tests during implementation planning. Copy the class/function signatures exactly as they appear in the stub file.

**Behavior sections are grounded in source definitions.** Read the actual source definitions of every class, function, and type the task doc references — base classes, config models, return types, dependency interfaces, fixture implementations. Inline the relevant details into the task doc so the implementing model has everything it needs.

Read `references/task-doc-guide.md` for the complete set of formatting principles for small models.

Key principles:
- **Self-contained.** Inline all relevant context.
- **Explicit file paths** from project root.
- **Interface contracts, not implementation code** (for service tasks).
- **Tests are referenced by path, not embedded.** The `## Tests` section points to the on-disk test file path. See `task-template.md` § "Tests".
- **Component tasks create files only — never modify shared files.**
- **Infrastructure tasks:** The Dockerfile and test compose are scaffold (already on disk). The model creates only the production compose file.

**Deferred vs service-gated:** See `references/task-doc-guide.md` § "Deferred Tasks vs Service-Gated Tasks".

### 4. Generate the Manifest

Create `00-manifest.json`. The `tooling` block holds global defaults. Tasks can override `lint_cmd` individually — infrastructure tasks always should.

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
      "files_created": ["services/my-service/config/settings.py"],
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
        "services/my-service/deployment/service.compose.yml"
      ],
      "files_modified": [],
      "lint_cmd": "./docs/plans/my-tasks/infra-lint.sh",
      "test_command": "bash docs/plans/my-tasks/smoke-test-my-service.sh",
      "pre_validated": true,
      "estimated_complexity": "simple",
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
      "service_compose": "services/my-service/deployment/services.compose.yml",
      "service_check_commands": {
        "minio": "curl -sf http://localhost:9000/minio/health/live",
        "rabbitmq": "curl -sf http://localhost:15672/api/overview -u guest:guest"
      },
      "depends_on": ["7.1"]
    }
  ]
}
```

Note: `requires_services` is a hard requirement. When services are unavailable and `service_compose` is set, the runner starts that compose file automatically, runs the task, and tears it down after. When `service_compose` is not set, the runner exits with an error.

### 5. Generate the Runner Script

Copy `scripts/run-tasks-template.sh` verbatim into the output folder as `run-tasks.sh`. Do NOT rewrite it.

**Do not restore `run-tasks.sh` from git history.** Always copy from the template.

After copying, make exactly two targeted edits if needed:
- `DEFAULT_MODEL` — update if the project uses a different local model
- `PROJECT_ROOT` path calculation — update if the tasks folder depth differs

### 6. Present Results

Summarize what was generated: N task files, M infrastructure tasks with smoke tests, manifest, runner. Include the phase breakdown and commands to run.

## Bundled Resources

| Resource | When to read |
|----------|-------------|
| `task-template.md` | Step 3 — complete template with all sections |
| `references/task-doc-guide.md` | Step 3 — formatting principles for small models |
| `scripts/run-tasks-template.sh` | Step 5 — copy verbatim, make two targeted edits |
