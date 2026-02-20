# Test & Lint Tooling Reference

## How Auto-Validation Works

From the [aider docs](https://aider.chat/docs/usage/lint-test.html) and [options reference](https://aider.chat/docs/config/options.html):

**Linting:**
- `--lint-cmd CMD` — defines the lint command. Per aider docs: "The lint command should accept the filenames of the files to lint." Aider appends the edited filenames as arguments.
- `--auto-lint` — runs lint after each edit. **Defaults to TRUE** — we pass it explicitly for clarity.

**Testing:**
- `--test-cmd CMD` — defines the test command. Per aider docs: "Aider will run the test command without any arguments." No filenames appended.
- `--auto-test` — runs tests after each edit. **Defaults to FALSE** — we pass it explicitly to opt in.

When aider can't fix a lint/test failure after several attempts, it exits non-zero. The runner halts and tells the user which task failed and how to resume.

### Critical: How aider invokes lint commands

Since aider appends edited filenames to the lint command, paths must make sense from aider's working directory (project root). For example, if the lint command is `cd services/foo && ruff check .` and aider edits `services/foo/bar.py`, aider runs:

```bash
cd services/foo && ruff check . services/foo/bar.py
```

This breaks because after `cd services/foo`, the path `services/foo/bar.py` doesn't exist (it would be just `bar.py` from that working directory).

The lint command must work from the project root. For monorepos, use the lint wrapper script instead of `cd`.

Test commands don't have this problem — aider runs them exactly as given, no filenames appended.

### Ruff must be run through the lint wrapper script

Aider appends *every* edited filename to the lint command, including non-Python files like `requirements.txt`, `.gitkeep`, `Dockerfile`, etc. Ruff will try to parse these as Python and report syntax errors the small model can never fix — it enters an infinite retry loop.

You might think ruff's `include` or `exclude` config would help, but ruff always lints files passed explicitly on the command line, regardless of config (per ruff docs: "Files that are passed to ruff directly are always linted"). The `force-exclude` setting helps but has edge cases with monorepo subdirectories.

The reliable solution is the lint wrapper script at `scripts/lint-ruff-wrapper.sh`. It:
1. Filters out non-Python files before they reach ruff
2. Runs ruff with `--fix` so trivially fixable issues (import sorting, unused imports) are auto-corrected instead of being sent to the small model

Copy the template into the tasks output directory as `lint.sh`, update the `RUFF_BIN` variable to point to the project's ruff binary, and use `./path/to/lint.sh` as the `lint_cmd` in the manifest.

### Lint command patterns

**Single project (ruff on PATH):**
```
RUFF_BIN="ruff"
lint_cmd: ./docs/plans/my-tasks/lint.sh
```

**Monorepo with venv:**
```
RUFF_BIN="services/airflow-ingestion/.venv/bin/ruff"
lint_cmd: ./docs/plans/airflow-tasks/lint.sh
```

**Monorepo with uv:**
```
RUFF_BIN="uv run --project services/airflow-ingestion ruff"
lint_cmd: ./docs/plans/airflow-tasks/lint.sh
```

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

### Step 3: Install All Dependencies

Install the project's actual dependencies *in addition to* lint and test tools. Tests will fail with `ModuleNotFoundError` if only ruff and pytest are installed but the project's libraries (e.g. `google-api-python-client`, `pydantic`, `boto3`) are missing.

Use whatever package manager the project uses. If there's no existing convention, prefer uv for new Python projects but ask the user if uncertain.

**Python with uv:**
```bash
cd services/airflow-ingestion
uv init --python 3.11
uv add --dev ruff pytest
uv sync                        # installs all deps including dev
uv run ruff check .            # verify lint
uv run pytest tests/ -v        # verify tests
```

**Python with pip + venv:**
```bash
cd services/airflow-ingestion
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt  # project dependencies
pip install ruff pytest          # if not already in requirements
ruff check .                     # verify lint
pytest tests/ -v                 # verify tests
```

**Python with poetry:**
```bash
cd services/airflow-ingestion
poetry add --group dev ruff pytest
poetry install                   # installs all deps
poetry run ruff check .
poetry run pytest tests/ -v
```

### Step 4: Create Minimal Test Infrastructure

1. Config file with lint and test sections
2. Test directory (`tests/__init__.py`, `tests/conftest.py`)
3. Smoke test that proves the toolchain works
4. Run and verify both commands exit 0

### Step 5: Set Up the Lint Wrapper

Copy `scripts/lint-ruff-wrapper.sh` into the tasks output directory as `lint.sh`. Update the `RUFF_BIN` variable to point to the project's ruff binary. Make it executable.

Test it by passing a mix of Python and non-Python files:
```bash
chmod +x docs/plans/my-tasks/lint.sh
./docs/plans/my-tasks/lint.sh services/foo/bar.py services/foo/requirements.txt
# Should only lint bar.py, skip requirements.txt
```

### Step 6: Record Commands for the Manifest

The lint command points to the wrapper script. The test command runs directly (since aider doesn't append filenames to it, `cd` is safe).

**Monorepo with venv example:**
```json
{
  "tooling": {
    "lint_cmd": "./docs/plans/airflow-tasks/lint.sh",
    "test_cmd": "cd services/airflow-ingestion && .venv/bin/pytest -x -q",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  }
}
```

**Monorepo with uv example:**
```json
{
  "tooling": {
    "lint_cmd": "./docs/plans/airflow-tasks/lint.sh",
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
    "lint_cmd": "./docs/plans/my-tasks/lint.sh",
    "test_cmd": "pytest -x -q",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  }
}
```

### If Setup Already Exists

If the project already has working tooling, don't reinstall — verify the commands work from the project root and record them. You still need the lint wrapper for aider compatibility.

## Common Tooling by Language

| Language | Linter | Test Framework | Lint Wrapper Needed? |
|----------|--------|---------------|-----|
| Python | ruff | pytest | Yes — use `scripts/lint-ruff-wrapper.sh` |
| Kotlin | ktlint (via Gradle plugin) | JUnit (via Gradle) | Probably not — Gradle tasks ignore non-source files |
| TypeScript | ESLint | Jest or Vitest | Maybe — ESLint ignores non-JS files by default, but test if aider passes unexpected files |
| Rust | clippy | cargo test | No — clippy only processes .rs files |
| Go | golangci-lint | go test | No — golangci-lint only processes .go files |

For languages not listed, check whether the linter handles non-source files gracefully when passed explicitly. If not, create a language-specific wrapper in `scripts/` following the pattern in `lint-ruff-wrapper.sh`.
