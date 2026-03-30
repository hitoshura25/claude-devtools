# Phase 1: Pipeline Analysis — Detailed Guidance

## Task Decomposition Validation

Load `tasks/<feature>/tasks.json` and validate it against the colocated
`task_schema.py`:

```bash
cd <project-root>
uv run --with pydantic python -c "
import sys
sys.path.insert(0, 'tasks/<feature>')
from task_schema import TaskDecomposition
d = TaskDecomposition.model_validate_json(open('tasks/<feature>/tasks.json').read())
print(f'Valid: {len(d.tasks)} tasks')
for t in d.tasks_in_order():
    print(f'  {t.id} [{t.task_type.value}] ({t.phase.value}): {t.title}')
"
```

If validation fails, stop and report the error. The decomposition needs fixing
before the pipeline can be generated.

After validation, extract these metrics for the user:
- Total task count
- Breakdown by type (test vs implementation)
- Breakdown by phase (scaffold, core, integration, testing, infrastructure)
- Dependency depth (longest chain from a root task to a leaf task)
- Count of tasks with tests vs without

## Working Directory and Tooling Detection

### Why Working Directory Matters

This is the single most important detection step. Aider runs lint and test
commands from whatever `cwd` it's given. Lint tools (ruff, eslint, ktlint) and
test runners (pytest, jest, gradle) are typically installed local to a service
or package directory — not globally. If Aider runs from the project root but
the tools are only available inside `services/my-service/`, every lint and test
invocation will fail with "command not found."

Additionally, Aider appends edited filenames as paths relative to its cwd to
the lint command. This is a documented Aider behavior that the pipeline must
account for (see Aider issue #1579 for monorepo context).

The pipeline must determine the correct working directory for each task's
Aider invocation. When Aider's cwd matches the service directory, lint and
test tools installed there are on the PATH, and file paths are relative to
that directory.

### Determining the Service Root

Look at the file paths in `tasks.json`. Most tasks create files under a common
prefix (e.g., `services/airflow-ingestion/plugins/...`). This common prefix is
the **service root** — the directory where tooling is installed and commands
should run from.

To detect it:
1. Collect all file paths from all tasks
2. Find the longest common directory prefix
3. Verify this directory contains tooling config (e.g., `pyproject.toml`,
   `package.json`, `build.gradle`, `Makefile`)

If tasks span multiple directories (e.g., some files in `services/my-service/`
and others in `deployment/`), you need per-task working directory assignment.
See "Per-Task Working Directory" below.

### Lint Command Detection

Once the service root is identified, check for tooling config within it:

1. **`pyproject.toml [tool.ruff]`** or **`ruff.toml`** → `ruff check`
2. **`.flake8`** or **`setup.cfg [flake8]`** → `flake8`
3. **`package.json`** with eslint dependency → `npx eslint`
4. **`build.gradle*`** with ktlint → `ktlint`

The lint command should be a bare tool name (e.g., `ruff check`) that works
when run from the service root. Do NOT use absolute paths or `cd` wrappers —
set Aider's cwd to the service root instead, so the tool is naturally on PATH.

**Verify it works:** Run the detected lint command from the service root
directory and confirm it exits cleanly on an existing file. If it fails with
"command not found," the tool isn't installed or isn't on PATH from that
directory. Ask the user how to invoke it.

Also check whether the prototype created a lint wrapper script — look in
`prototypes/<feature>/` for `lint.sh` or similar. If one exists, note it as
an alternative.

### Test Runner Detection

Check within the service root for:

1. **`pyproject.toml [tool.pytest]`** or **`pytest.ini`** or **`conftest.py`**
   → test framework is `pytest`
2. **`package.json`** with jest dependency → `jest`
3. **`build.gradle*`** with test tasks → JUnit/Kotlin test

### Language Detection

Infer from task file paths:
- `.py` files → Python
- `.ts`/`.js` files → TypeScript/JavaScript
- `.kt` files → Kotlin

## Per-Task Working Directory

Most tasks share the same service root as their working directory. But some
tasks (infrastructure, deployment) may create files outside the service tree.

For each task, determine the working directory:

1. Look at the task's `files` list
2. If all files share the service root prefix → cwd = service root
3. If files are at the project root (e.g., `docker-compose.yml`,
   `Dockerfile` at root) → cwd = project root
4. If files span multiple directories → cwd = their common ancestor

Store this as a per-task config: `TASK_WORKING_DIRS: dict[str, str]`.

When a task's working directory is the service root, Aider receives file paths
relative to that service root. The pipeline must **rebase** the task's absolute
file paths (from `tasks.json`, which are relative to project root) to be
relative to the task's working directory.

Example: task file path `services/airflow-ingestion/plugins/client.py` with
service root `services/airflow-ingestion/` → Aider receives `--file plugins/client.py`.

### File Path Rebasing

For each task:
1. Get the task's working directory
2. For each file in the task's `files` list, strip the working directory prefix
   to get the path relative to the cwd
3. Pass the rebased paths as `--file` arguments to Aider

```
project root:    /Users/me/my-project/
service root:    /Users/me/my-project/services/my-service/
task file path:  services/my-service/plugins/client.py    (from tasks.json)
rebased path:    plugins/client.py                         (for --file arg)
aider cwd:       /Users/me/my-project/services/my-service/
```

If a file path does NOT start with the working directory prefix, it can't be
rebased — the file is outside the working directory. In that case, either use
the project root as cwd for that task, or flag it as an error.

## Per-Task Test Command Derivation

For each task in `tasks.json`, derive the test command:

### Test tasks (`task_type: "test"`)

Test tasks write test files. Their verification is:
1. The test file is syntactically valid (importable)
2. The tests fail because implementation doesn't exist yet

Command: `<test-runner> <test_file_path> -x` (expect non-zero exit = correct)

Test file paths in the `tests` field must also be rebased relative to the
task's working directory.

For test tasks, the pipeline needs inverted verification logic: the test command
should *fail* (non-zero exit). If it passes, something is wrong — the tests
should fail because there's no implementation yet.

However, Aider's `--auto-test` expects the test to pass. So for test tasks,
do NOT use `--auto-test` with Aider. Instead, use `--auto-lint` only. The
pipeline's `verify_task` node handles the inverted check independently.

### Implementation tasks (`task_type: "implementation"`)

Implementation tasks write production code. Their verification is:
1. All previously-written tests pass
2. Lint passes

Collect all unique `test_file` paths from the task's `tests` list. Rebase them
relative to the working directory. Construct:
`<test-runner> <rebased_test_file_1> <rebased_test_file_2> ... -x`

For implementation tasks, use both `--auto-lint` and `--auto-test` with Aider.

### Tasks with no tests

Scaffold tasks, config tasks, and infrastructure tasks may have empty `tests`
lists. These get `--auto-lint` only, no test gate.

## Deriving the Test Command Pattern

Build the full command from detected framework + project structure:

| Framework | Base pattern | Example |
|-----------|-------------|---------|
| pytest | `pytest <files> -x` | `pytest tests/test_client.py -x` |
| jest | `npx jest <files>` | `npx jest tests/client.test.ts` |
| JUnit/Gradle | `./gradlew test --tests '<pattern>'` | `./gradlew test --tests 'ClientTest'` |

Note: test file paths in the command are relative to the task's working
directory (the same directory that Aider uses as cwd). This is why rebasing
matters — everything is relative to the same root.

## Model Availability Check

Check if LM Studio is reachable:

```bash
curl -s http://localhost:1234/v1/models
```

If reachable, parse the response to find available models. Note the model name
for `config.py`. If not reachable, note it as a prerequisite — the pipeline
will fail at runtime if LM Studio isn't running, which is expected.

Also check what model the user has been using. The `run-tasks-template.sh` from
agent-ready-plans uses `lm_studio/qwen/qwen3-coder-30b` as the default. Ask the
user to confirm their model string if it can't be detected.

## Aider Availability Check

```bash
which aider
aider --version
```

If not found, note the installation command: `pip install aider-chat` (or
`uv tool install aider-chat`).

## Presentation

Present the analysis as a structured summary:

```
## Pipeline Analysis: <feature-name>

### Tasks
- Total: N tasks (T test + I implementation)
- Phases: scaffold (S), core (C), integration (I), testing (T), infrastructure (F)
- Dependency depth: D

### Working Directory
- Service root: `services/my-service/` (detected from file path analysis)
- Tasks using service root: 25/27
- Tasks using project root: 2/27 (task-26: Dockerfile, task-27: integration)

### Detected Tooling (from service root)
- Language: Python
- Lint command: `ruff check` (from service root)
- Test runner: `pytest`

### Per-Task Summary
| Task ID | Type | Working Dir | Lint | Test Command | Verification |
|---------|------|-------------|------|--------------|--------------|
| task-01 | impl | service root | ruff check | (none) | lint only |
| task-02 | test | service root | ruff check | `pytest tests/test_client.py -x` | expect failure |
| task-03 | impl | service root | ruff check | `pytest tests/test_client.py -x` | expect pass |
| task-26 | impl | project root | (none) | (none) | lint skip |
| ... | | | | | |

### Prerequisites
- [✓/✗] Aider installed (version X.Y.Z)
- [✓/✗] LM Studio reachable at localhost:1234
  - Model: <detected or ask>
- [✓/✗] Lint command works from service root
- [✓/✗] Test runner works from service root

### Questions
1. <Any ambiguities to confirm>
```

Ask the user to confirm the detected working directories and commands before
proceeding.
