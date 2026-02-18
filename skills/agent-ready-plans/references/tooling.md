# Test & Lint Tooling Reference

## How Auto-Validation Works

The runner script passes four aider flags that create an automatic validation loop:

- `--lint-cmd "..."` — defines the lint command
- `--auto-lint` — aider runs the lint command after each edit; if it fails, aider attempts to fix
- `--test-cmd "..."` — defines the test command
- `--auto-test` — aider runs the test command after each edit; if it fails, aider attempts to fix

When aider can't fix a lint/test failure after several attempts, it exits non-zero. The runner halts and tells the user which task failed and how to resume.

## Common Tooling by Language

| Language | Lint Command | Test Command |
|----------|-------------|-------------|
| Python | `ruff check .` | `python -m pytest -x -q` |
| Kotlin | `./gradlew ktlintCheck` | `./gradlew test` |
| TypeScript | `npx eslint .` | `npx jest` or `npx vitest run` |
| Rust | `cargo clippy` | `cargo test` |
| Go | `golangci-lint run` | `go test ./...` |

## Task 01: Test & Lint Setup

The first task in every plan sets up the test and lint infrastructure. This matters because all subsequent tasks use `--auto-lint` and `--auto-test` — if the tooling isn't configured, every task fails before it starts.

Task 01 should:

1. Install/configure the test framework (e.g. pytest + conftest.py, jest + config)
2. Install/configure the linter (e.g. ruff section in pyproject.toml, eslint + .eslintrc)
3. Create a minimal smoke test that proves the toolchain works
4. Verify both commands exit successfully

If the implementation plan already includes a test/lint setup task, use it as Task 01 — just make sure lint and test commands are validated at the end.

### Python Example

```markdown
# Task 01: Test & Lint Setup

> **Phase:** Project Scaffolding
> **Original Task:** 0.0 (generated)
> **Complexity:** simple

## Project Context
[standard context block]

## Objective
Set up pytest and ruff so that all subsequent tasks are automatically validated.

## Files to Create
- `services/airflow-ingestion/pyproject.toml`
- `services/airflow-ingestion/tests/__init__.py`
- `services/airflow-ingestion/tests/conftest.py`
- `services/airflow-ingestion/tests/test_smoke.py`

## Instructions

### Step 1: Create pyproject.toml with test and lint config
Create `services/airflow-ingestion/pyproject.toml`:
[full file content with pytest and ruff sections]

### Step 2: Create test directory and conftest
Create `services/airflow-ingestion/tests/__init__.py` (empty)
Create `services/airflow-ingestion/tests/conftest.py`:
[conftest with shared fixtures]

### Step 3: Create smoke test
Create `services/airflow-ingestion/tests/test_smoke.py`:
[minimal test that asserts True — proves pytest works]

### Step 4: Verify toolchain
Run:
  ruff check services/airflow-ingestion/
  cd services/airflow-ingestion && python -m pytest tests/test_smoke.py -v

Expected: lint passes with 0 errors, 1 test passes.

### Step 5: Commit
git add services/airflow-ingestion/pyproject.toml services/airflow-ingestion/tests/
git commit -m "chore: set up pytest and ruff for airflow-ingestion service"
```

## Manifest Tooling Section

The manifest's `tooling` block tells the runner script which commands to use:

```json
{
  "tooling": {
    "lint_cmd": "ruff check .",
    "test_cmd": "cd services/airflow-ingestion && python -m pytest -x -q",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  }
}
```

The runner reads `lint_cmd` and `test_cmd` from this block. CLI flags `--lint-cmd` and `--test-cmd` override these values if provided.
