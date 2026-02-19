# Test & Lint Tooling Reference

## How Auto-Validation Works

From the [aider docs](https://aider.chat/docs/usage/lint-test.html) and [options reference](https://aider.chat/docs/config/options.html):

**Linting:**
- `--lint-cmd CMD` — defines the lint command. Per aider docs: "The lint command should accept the filenames of the files to lint." Aider appends the edited filenames as arguments.
- `--auto-lint` — runs lint after each edit. **Defaults to TRUE** — it's on by default, so no flag needed. Use `--no-auto-lint` to disable.

**Testing:**
- `--test-cmd CMD` — defines the test command. Per aider docs: "Aider will run the test command without any arguments." No filenames appended.
- `--auto-test` — runs tests after each edit. **Defaults to FALSE** — must explicitly opt in with `--auto-test`.

When aider can't fix a lint/test failure after several attempts, it exits non-zero. The runner halts and tells the user which task failed and how to resume.

### Critical: How aider invokes lint commands

Since aider appends edited filenames to the lint command, paths must make sense from aider's working directory (project root). For example, if the lint command is `cd services/foo && ruff check .` and aider edits `services/foo/bar.py`, aider runs:

```bash
cd services/foo && ruff check . services/foo/bar.py
```

This breaks because after `cd services/foo`, the path `services/foo/bar.py` doesn't exist (it would be just `bar.py` from that working directory).

The lint command must work from the project root. For monorepos, use a wrapper script or full-path approach instead of `cd`.

Test commands don't have this problem — aider runs them exactly as given, no filenames appended.

### Lint command patterns that work with aider

**Single project (tools at project root):**
```
lint_cmd: ruff check .
```

**Monorepo with venv (use the venv binary directly with a config path):**
```
lint_cmd: services/airflow-ingestion/.venv/bin/ruff check services/airflow-ingestion/
```
This works because paths are always relative to project root — aider's appended filenames will also be relative to project root.

**Monorepo with uv:**
```
lint_cmd: uv run --project services/airflow-ingestion ruff check services/airflow-ingestion/
```

**Wrapper script approach (most flexible):**
Create a small `lint.sh` in the tasks output directory:
```bash
#!/usr/bin/env bash
# Lint wrapper — handles path translation for aider's --auto-lint
# aider appends edited filenames as extra args
exec services/airflow-ingestion/.venv/bin/ruff check "$@"
```
Then: `lint_cmd: ./docs/plans/my-tasks/lint.sh`

When aider appends files, it becomes `./lint.sh services/airflow-ingestion/bar.py` — which works correctly.

### Ruff must be configured to only check Python files

Aider appends *every* edited filename to the lint command, including non-Python files like `requirements.txt`, `.gitkeep`, `Dockerfile`, etc. By default ruff will try to parse these as Python and report syntax errors that the small model can never fix — it enters an infinite retry loop.

When configuring ruff in `pyproject.toml`, always include an explicit `include` directive:

```toml
[tool.ruff]
include = ["*.py", "*.pyi"]
```

This tells ruff to only check Python source files, regardless of what filenames aider passes to it. Non-Python files get silently skipped instead of producing unfixable errors.

## Discovering the Right Setup

Every project manages dependencies and tooling differently. Investigate the project first, then set up tooling consistent with what's already there.

### Step 1: Investigate the Project

Before installing anything, check what already exists:

**Package manager indicators:**
- `pyproject.toml` with `[tool.uv]` or `uv.lock` → project uses **uv**
- `pyproject.toml` with `[tool.poetry]` or `poetry.lock` → project uses **poetry**
- `Pipfile` or `Pipfile.lock` → project uses **pipenv**
- `requirements.txt` only → project uses plain **pip** (consider suggesting uv)
- `package.json` → Node.js, check for npm/yarn/pnpm lockfiles
- `build.gradle` / `build.gradle.kts` → Kotlin/Java with Gradle
- `Cargo.toml` → Rust with cargo

**Virtual environment indicators:**
- `.venv/` or `venv/` in the project or service directory → existing venv
- `.python-version` → pyenv or uv-managed Python version

**Monorepo indicators:**
- Multiple `pyproject.toml` files in different subdirectories → per-service environments
- Top-level `pyproject.toml` with workspace config → monorepo workspace
- `services/`, `packages/`, or `apps/` directory structure → multi-service layout

**Existing tooling:**
- `[tool.ruff]` section in pyproject.toml → ruff already configured
- `[tool.pytest.ini_options]` → pytest already configured
- `.eslintrc.*` / `eslint.config.*` → ESLint configured

### Step 2: Determine the Scope

For a monorepo, tooling setup belongs to the specific service, not the root. Check the implementation plan for the service directory.

| Project Structure | Environment Scope | Config Location |
|---|---|---|
| Single project | Project root | `./pyproject.toml` |
| Monorepo, per-service | Service directory | `services/my-service/pyproject.toml` |
| Monorepo, shared workspace | Project root with workspaces | Root `pyproject.toml` with workspace members |

### Step 3: Set Up Consistently

Use whatever package manager the project already uses. If no convention exists, prefer uv for new Python projects but ask the user if uncertain.

**Python with uv:**
```bash
cd services/airflow-ingestion
uv init --python 3.11
uv add --dev ruff pytest
uv run ruff check .            # verify
uv run pytest tests/ -v        # verify
```

**Python with pip + venv:**
```bash
cd services/airflow-ingestion
python -m venv .venv
source .venv/bin/activate
pip install ruff pytest
ruff check .                   # verify
pytest tests/ -v               # verify
```

**Python with poetry:**
```bash
cd services/airflow-ingestion
poetry add --group dev ruff pytest
poetry run ruff check .
poetry run pytest tests/ -v
```

### Step 4: Create Minimal Test Infrastructure

1. Config file with lint and test sections. For ruff, the config must include `include = ["*.py", "*.pyi"]` so that non-Python files (requirements.txt, .gitkeep, etc.) passed by aider are silently skipped instead of causing unfixable parse errors.
2. Test directory (`tests/__init__.py`, `tests/conftest.py`)
3. Smoke test that proves the toolchain works
4. Run and verify both commands exit 0

### Step 5: Record Commands for the Manifest

The lint and test commands must work when executed from the **project root** (where aider runs). Remember: aider appends filenames to the lint command, so avoid `cd` in lint_cmd.

**Monorepo with venv example:**
```json
{
  "tooling": {
    "lint_cmd": "services/airflow-ingestion/.venv/bin/ruff check services/airflow-ingestion/",
    "test_cmd": "cd services/airflow-ingestion && .venv/bin/pytest -x -q",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  }
}
```

Note: `lint_cmd` does NOT use `cd` (because aider appends files). `test_cmd` CAN use `cd` (aider runs it as-is).

**Monorepo with uv example:**
```json
{
  "tooling": {
    "lint_cmd": "uv run --project services/airflow-ingestion ruff check services/airflow-ingestion/",
    "test_cmd": "cd services/airflow-ingestion && uv run pytest -x -q",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  }
}
```

**Single project example:**
```json
{
  "tooling": {
    "lint_cmd": "ruff check .",
    "test_cmd": "pytest -x -q",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  }
}
```

### If Setup Already Exists

If the project already has working tooling, don't reinstall — verify the commands work from the project root and record them.

## Common Tooling by Language

| Language | Linter | Test Framework | Notes |
|----------|--------|---------------|-------|
| Python | ruff | pytest | Prefer uv for new projects |
| Kotlin | ktlint (via Gradle plugin) | JUnit (via Gradle) | Managed through build.gradle |
| TypeScript | ESLint | Jest or Vitest | Managed through package.json |
| Rust | clippy | cargo test | Built into the toolchain |
| Go | golangci-lint | go test | Lint needs separate install |
