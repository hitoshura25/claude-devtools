# Test & Lint Tooling Reference

## How Auto-Validation Works

The runner script passes four aider flags that create an automatic validation loop:

- `--lint-cmd "..."` — defines the lint command
- `--auto-lint` — aider runs the lint command after each edit; if it fails, aider attempts to fix
- `--test-cmd "..."` — defines the test command
- `--auto-test` — aider runs the test command after each edit; if it fails, aider attempts to fix

When aider can't fix a lint/test failure after several attempts, it exits non-zero. The runner halts and tells the user which task failed and how to resume.

## Discovering the Right Setup

Every project manages dependencies and tooling differently. Rather than assuming a particular approach, investigate the project first and then set up tooling in a way that's consistent with what's already there.

### Step 1: Investigate the Project

Before installing anything, check what already exists. Look for these signals:

**Package manager indicators:**
- `pyproject.toml` with `[tool.uv]` or `uv.lock` → project uses **uv**
- `pyproject.toml` with `[tool.poetry]` or `poetry.lock` → project uses **poetry**
- `Pipfile` or `Pipfile.lock` → project uses **pipenv**
- `requirements.txt` only → project uses plain **pip** (consider suggesting uv)
- `setup.py` / `setup.cfg` → older Python project, likely pip-based
- `package.json` → Node.js, check for npm/yarn/pnpm lockfiles
- `build.gradle` / `build.gradle.kts` → Kotlin/Java with Gradle
- `Cargo.toml` → Rust with cargo

**Virtual environment indicators:**
- `.venv/` or `venv/` in the project or service directory → existing venv
- `.python-version` → pyenv or uv-managed Python version
- `Dockerfile` with `pip install` → containerized, might not need local venv

**Monorepo indicators:**
- Multiple `pyproject.toml` files in different subdirectories → per-service environments
- Top-level `pyproject.toml` with workspace config → monorepo workspace
- `services/`, `packages/`, or `apps/` directory structure → multi-service layout

**Existing tooling:**
- `[tool.ruff]` section in pyproject.toml → ruff already configured
- `[tool.pytest.ini_options]` → pytest already configured
- `.eslintrc.*` / `eslint.config.*` → ESLint configured
- `jest.config.*` / `vitest.config.*` → test runner configured

### Step 2: Determine the Scope

For a monorepo, tooling setup belongs to the specific service being implemented, not the root. Check the implementation plan — it usually specifies a service directory (e.g. `services/airflow-ingestion/`).

Ask: where should the virtual environment and config live?

| Project Structure | Environment Scope | Config Location |
|---|---|---|
| Single project | Project root | `./pyproject.toml` |
| Monorepo, per-service | Service directory | `services/my-service/pyproject.toml` |
| Monorepo, shared workspace | Project root with workspaces | Root `pyproject.toml` with workspace members |

### Step 3: Set Up in a Way That Matches the Project

Use whatever package manager the project already uses. If there's no existing convention, prefer uv for new Python projects (it's faster and handles Python versions), but ask the user if uncertain.

**Python with uv:**
```bash
cd services/airflow-ingestion
uv init --python 3.11          # if no pyproject.toml exists yet
uv add --dev ruff pytest       # adds to [dependency-groups] dev
uv run ruff check .            # verify lint
uv run pytest tests/ -v        # verify tests
```
The runner's lint/test commands would then be prefixed with `uv run`:
- lint_cmd: `cd services/airflow-ingestion && uv run ruff check .`
- test_cmd: `cd services/airflow-ingestion && uv run pytest -x -q`

**Python with pip + venv:**
```bash
cd services/airflow-ingestion
python -m venv .venv
source .venv/bin/activate
pip install ruff pytest
ruff check .
pytest tests/ -v
```
The runner needs the venv activated, so commands become:
- lint_cmd: `cd services/airflow-ingestion && source .venv/bin/activate && ruff check .`
- test_cmd: `cd services/airflow-ingestion && source .venv/bin/activate && pytest -x -q`

**Python with poetry:**
```bash
cd services/airflow-ingestion
poetry add --group dev ruff pytest
poetry run ruff check .
poetry run pytest tests/ -v
```

**TypeScript with npm:**
```bash
npm install -D eslint jest @types/jest ts-jest
npx eslint .
npx jest
```

**Kotlin with Gradle:**
```kotlin
// build.gradle.kts — add ktlint plugin
plugins { id("org.jlleitschuh.gradle.ktlint") }
```

### Step 4: Create Minimal Test Infrastructure

After tools are installed, create the minimum needed to prove they work:

1. **Config file** — if one doesn't exist, create it with lint and test sections appropriate to the project's conventions
2. **Test directory** — `tests/__init__.py`, `tests/conftest.py` (or equivalent)
3. **Smoke test** — a trivial test that verifies the test runner works
4. **Run and verify** — both lint and test commands must exit 0

### Step 5: Record the Commands

Once verified, the lint and test commands go into the manifest's `tooling` section. These are the exact commands the runner will use — they must work when executed from the project root.

```json
{
  "tooling": {
    "lint_cmd": "cd services/airflow-ingestion && uv run ruff check .",
    "test_cmd": "cd services/airflow-ingestion && uv run pytest -x -q",
    "language": "python",
    "framework": "pytest",
    "linter": "ruff"
  }
}
```

### If Setup Already Exists

If the project already has working lint and test tooling, don't reinstall — just verify the commands work and record them. The goal is to discover and validate, not to impose.

## Common Tooling by Language

For reference when the project doesn't have existing tooling:

| Language | Linter | Test Framework | Notes |
|----------|--------|---------------|-------|
| Python | ruff | pytest | Prefer uv for dependency management in new projects |
| Kotlin | ktlint (via Gradle plugin) | JUnit (via Gradle) | Managed through build.gradle |
| TypeScript | ESLint | Jest or Vitest | Managed through package.json |
| Rust | clippy | cargo test | Built into the toolchain |
| Go | golangci-lint | go test | Lint needs separate install |
