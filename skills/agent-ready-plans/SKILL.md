---
name: agent-ready-plans
description: Decompose implementation plans into individual task files for smaller AI coding agents like aider running local models (Qwen Coder, Codestral) via LMStudio. Claude Code writes and validates the tests; the small model implements the code to make them pass. Use this skill whenever someone says "decompose this plan", "break this into aider tasks", "create task files for local agents", "make this plan agent-ready", or wants to delegate implementation to smaller models. Also trigger when a user has a design doc + implementation plan and mentions aider, LMStudio, local models, or task decomposition — even if they don't explicitly say "agent-ready".
---

# Agent-Ready Plans

Translate a design document + implementation plan into self-contained task files that smaller AI coding agents can execute sequentially. Each task is an aider `--message-file` with an interface contract, behavioral specs, and a reference to pre-written tests — everything a small model needs to implement and test one component.

The key insight: Claude Code writes complete, verified tests for each task and saves them to disk. The small model implements the code to make them pass. Claude Code owns test correctness — the small model owns implementation.

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

Task numbering starts at Phase 2 because Phase 1 (scaffold) is created directly by Claude Code in Step 3.

## Process

### 0. Check for Stale Git Artifacts — Do This First

Check whether output files from a previous run exist in git history:

```bash
git ls-tree -r HEAD --name-only | grep "docs/plans/.*-tasks/"
```

If previous files appear in HEAD, **do not restore them with `git checkout HEAD`**. Those files are stale — the user deleted them to trigger a fresh regeneration. Proceed with the full process from Step 1.

### 1. Read and Analyze

Read both the design doc and implementation plan. Build a mental model of total tasks, dependencies, interface contracts, and the project's language/tooling.

**Scan for infrastructure tasks:** Check whether any task's `files_created` includes `Dockerfile`, `*compose*.yml`, `*.tf`, or Kubernetes YAML. These require different tooling — flag them now.

### 2. Determine Test & Lint Tooling

Read `references/tooling.md` for the discovery process. Then read the appropriate `references/stacks/<language>-<framework>.md`.

If infrastructure tasks were flagged, also read `references/stacks/infra.md` — infrastructure tasks use hadolint and Docker smoke tests, and the manifest supports per-task `lint_cmd` overrides.

**Every task must have a test.** Service tasks get unit tests; infrastructure tasks get Docker smoke tests.

### 3. Set Up Tooling and Scaffold (execute directly)

Install tooling and create the project scaffold *right now* — do not delegate to task files. Small models can write business logic but can't debug missing tools, broken configs, or subtle test setup.

**Tooling setup:** Read `references/tooling.md` and the appropriate stack files. Investigate existing project conventions first.

If infrastructure tasks are present:
- Install `hadolint` (see `stacks/infra.md` § "Tooling Setup")
- Copy `scripts/infra-lint-wrapper-template.sh` → `infra-lint.sh`
- For each Docker/compose task, copy `scripts/docker-smoke-test-template.sh` and configure `COMPOSE_FILE` and `HEALTH_URL`
- Write the self-contained test compose file (see `stacks/infra.md` § "The Two-Compose Pattern")
- **Write and verify the Dockerfile as scaffold** (see `stacks/infra.md` § "Dockerfile as Scaffold"). Verify base image tags via `docker manifest inspect`, write the Dockerfile, build it, pin versions via `pip freeze`, rebuild, run hadolint. The validated Dockerfile stays on disk — the small model only creates compose files.

**Conftest fixtures (Python/pytest):** Read `references/stacks/python-pytest/fixture-patterns.md`. For each external dependency, pick the appropriate pattern (capture mock, client mock, or stateful fake), copy the template, and adjust patch paths. Follow the fixture interaction rules.

**Project scaffold:** Create these files directly (see Phase 1 in the plan):
- Build/package config with all dependencies, test config, lint config
- Test setup file with fixtures (from fixture-patterns.md templates)
- All package `__init__` files
- A stub file for each task (see Step 3b)

**Stub files must not execute code that requires runtime environment.** See `references/writing-guide.md` § "Stub Design".

After setup, verify both lint and test commands pass. Do NOT commit or stage any files.

### 3b. Write and Validate Task Tests

For each task, write its test file to disk now — before generating task documents.

Read `references/writing-guide.md` § "Writing Correct Tests" for the full rules.

**For service tasks:**

1. Write the test file against the stub
2. **Check fixture interaction rules** — verify in `python-pytest/fixture-patterns.md` § "Fixture Interaction Rules" that fixture combinations are valid
3. Run the mutation gate (see `references/tooling.md` § "Mutation Testing")
4. Run tests against the stub; verify all fail for the right reason
5. Replace stub bodies with "not implemented" once gates pass

**For infrastructure tasks:**

1. Verify the Dockerfile is on disk (created in Step 3 as scaffold) and passes hadolint
2. Confirm the smoke test script is configured correctly
3. Run the smoke test; confirm it fails appropriately against stubs (health timeout, not build failure)
4. Clean up the test build image: `docker rmi test-build-verify 2>/dev/null || true`

**Record validation results in the manifest** (Step 6): service tasks get `"pre_validated": true` and `"test_file"`. Infrastructure tasks get `"pre_validated": true` but no `"test_file"`.

### 4. Extract Project Context

Extract a shared context block from the design doc (10-15 lines max). Include: what the project does, tech stack, directory structure, lint/test commands, conventions, available fixtures. Always end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.`

### 5. Generate Task Documents

For each task (starting from Phase 2), generate a standalone markdown file. Read `task-template.md` for the complete template.

**Naming:** `NN-task-X.Y-short-description.md`

Key principles:
- **Self-contained.** Inline all relevant context.
- **Explicit file paths** from project root.
- **Interface contracts, not implementation code** (for service tasks).
- **Tests are referenced by path, not embedded.** The `## Tests` section points to the on-disk test file path — it does not contain a copy of the test code. This eliminates divergence between the validated test and what the model reads. See `task-template.md` § "Tests" for the format.
- **Component tasks create files only — never modify shared files.** See `references/writing-guide.md` § "Task Scope".
- **Infrastructure tasks:** The Dockerfile is scaffold (already on disk). The model creates only the compose files. Claude Code has already written the smoke test script. The task doc describes what compose files to create; it does not embed the smoke test script.

**Deferred vs service-gated:** See `references/writing-guide.md` § "Deferred Tasks vs Service-Gated Tasks".

### 6. Generate the Manifest

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
        "services/my-service/deployment/service.compose.yml",
        "services/my-service/deployment/service.test.compose.yml"
      ],
      "files_modified": [],
      "lint_cmd": "docs/plans/my-tasks/infra-lint.sh",
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
      "service_check_commands": {
        "minio": "curl -sf http://localhost:9000/minio/health/live",
        "rabbitmq": "curl -sf http://localhost:15672/api/overview -u guest:guest"
      },
      "depends_on": ["7.1"]
    }
  ]
}
```

Note: `requires_services` is a hard requirement — the runner exits if services are unavailable.

### 7. Generate the Runner Script

Copy `scripts/run-tasks-template.sh` verbatim into the output folder as `run-tasks.sh`. Do NOT rewrite it.

**Do not restore `run-tasks.sh` from git history.** Always copy from the template.

After copying, make exactly two targeted edits if needed:
- `DEFAULT_MODEL` — update if the project uses a different local model
- `PROJECT_ROOT` path calculation — update if the tasks folder depth differs

### 8. Present Results

Summarize what was generated: scaffold created, N task files, M infrastructure tasks with smoke tests, manifest, runner. Include the phase breakdown and commands to run.

## Bundled Resources

| Resource | When to read |
|----------|-------------|
| `task-template.md` | Step 5 — complete template with all sections |
| `references/tooling.md` | Steps 2, 3, 3b — tooling discovery, fixture criteria, mutation gate |
| `references/stacks/<language>-<framework>.md` | Steps 2, 3, 3b — language-specific tooling |
| `references/stacks/python-pytest/fixture-patterns.md` | Step 3 (conftest), Step 3b (test writing) — fixture templates, interaction rules |
| `references/stacks/infra.md` | Steps 2, 3, 3b — Docker/compose/Terraform tooling |
| `references/writing-guide.md` | Steps 3b, 5 — test correctness, stub design, task scope |
| `scripts/lint-ruff-wrapper.sh` | Step 3, Python/ruff — copy to tasks folder |
| `scripts/infra-lint-wrapper-template.sh` | Step 3, infra tasks — copy as `infra-lint.sh` |
| `scripts/docker-smoke-test-template.sh` | Step 3b, Docker tasks — copy per service |
| `scripts/run-tasks-template.sh` | Step 7 — copy verbatim, make two targeted edits |
