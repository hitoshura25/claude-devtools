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

## Tooling Detection

The prototype validated during the planning phase proves that lint and test
toolchains work. The pipeline needs to discover the exact commands by reading
project config files.

### Lint Command Detection

Check these locations in order (first match wins):

1. **`ruff.toml`** or **`pyproject.toml [tool.ruff]`** → lint command is `ruff check`
2. **`.flake8`** or **`setup.cfg [flake8]`** → lint command is `flake8`
3. **`pyproject.toml [tool.pylint]`** → lint command is `pylint`
4. **`eslint.config.*`** or **`.eslintrc.*`** → lint command is `eslint`
5. **`ktlint`** in build scripts → lint command is `ktlint`

Important: Aider appends edited filenames to the lint command. So the command
must accept filenames as trailing arguments. `ruff check` does this naturally.
If the project uses a wrapper script (like the planning skill sometimes creates
in the prototype), note that and use the wrapper.

Also check whether the prototype created a lint wrapper script — look in
`prototypes/<feature>/` for `lint.sh` or similar. If one exists and references
project-specific config, it may be the better lint command.

### Test Runner Detection

Check these locations:

1. **`pyproject.toml [tool.pytest]`** or **`pytest.ini`** or **`conftest.py`**
   → test framework is `pytest`
2. **`jest.config.*`** or **`package.json "jest"`** → test framework is `jest`
3. **`build.gradle* testImplementation`** → test framework is JUnit/Kotlin test

For Python projects using `uv`:
- Check if `.venv/` exists or `pyproject.toml` has `[project]` → prefix with
  `uv run` if the project uses uv
- Check if the prototype's test commands used `uv run pytest` vs bare `pytest`

### Language Detection

Infer from task file paths:
- `.py` files → Python
- `.ts`/`.js` files → TypeScript/JavaScript
- `.kt` files → Kotlin

## Per-Task Test Command Derivation

For each task in `tasks.json`, derive the test command:

### Test tasks (`task_type: "test"`)

Test tasks write test files. Their verification is:
1. The test file is syntactically valid (importable)
2. The tests fail because implementation doesn't exist yet

Command: `<test-runner> <test_file_path> -x` (expect non-zero exit = correct)

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

Collect all unique `test_file` paths from the task's `tests` list. Construct:
`<test-runner> <test_file_1> <test_file_2> ... -x`

For implementation tasks, use both `--auto-lint` and `--auto-test` with Aider.

### Tasks with no tests

Scaffold tasks, config tasks, and infrastructure tasks may have empty `tests`
lists. These get `--auto-lint` only, no test gate.

## Deriving the Test Command Pattern

Build the full command from detected framework + project structure:

| Framework | Base pattern | Example |
|-----------|-------------|---------|
| pytest | `pytest <files> -x` | `pytest tests/test_client.py -x` |
| pytest + uv | `uv run pytest <files> -x` | `uv run pytest tests/test_client.py -x` |
| jest | `npx jest <files>` | `npx jest tests/client.test.ts` |
| JUnit/Gradle | `./gradlew test --tests '<pattern>'` | `./gradlew test --tests 'ClientTest'` |

If the project has a working directory convention (e.g., tests must run from
`services/my-service/`), prepend the `cd` to the test command or note it for
the pipeline's working directory config. Check how the prototype runs its tests.

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

### Detected Tooling
- Language: Python
- Lint command: `ruff check`
- Test runner: `pytest` (via `uv run`)
- Global test command: `uv run pytest tests/ -x -q`

### Per-Task Test Commands
| Task ID | Type | Test Command | Verification |
|---------|------|--------------|--------------|
| task-01 | impl | (none — scaffold) | lint only |
| task-02 | test | `pytest tests/test_client.py -x` | expect failure |
| task-03 | impl | `pytest tests/test_client.py -x` | expect pass |
| ... | | | |

### Prerequisites
- [✓/✗] Aider installed (version X.Y.Z)
- [✓/✗] LM Studio reachable at localhost:1234
  - Model: <detected or ask>
- [✓/✗] Project lint command works
- [✓/✗] Project test runner works

### Questions
1. <Any ambiguities to confirm>
```

Ask the user to confirm the detected commands and model before proceeding.
