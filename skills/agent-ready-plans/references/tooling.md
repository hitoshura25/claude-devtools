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

## Creating External Dependency Mock Fixtures

Small models consistently fail at mocking external service clients. The pattern is always the same: the model writes a test that mocks a library like `google-api-python-client` or `boto3`, gets the mock wiring subtly wrong (fluent chain doesn't return the right mock, buffer write never happens, connection lifecycle doesn't match), then exhausts all its reflections trying to debug mock plumbing instead of writing business logic.

The fix: Claude Code creates reusable pytest fixtures in `conftest.py` during scaffold setup. These fixtures handle the tricky mock internals once, correctly. The small model's tests use them by name and only configure return values.

### When to Create a Fixture

Create a conftest fixture for any external dependency that meets these criteria:
- Has a fluent or chained API (e.g., `service.files().list().execute()`)
- Requires simulating I/O (downloads writing to buffers, uploads capturing bytes)
- Has a connect/use/close lifecycle (database connections, message brokers)
- **Has a positional argument trap** — a call where argument order is non-obvious, easy to swap, and wrong usage fails at runtime rather than definition time (see below)
- Is used by multiple tasks in the plan

Common candidates: Google API clients, boto3/S3, pika/RabbitMQ, database drivers, HTTP clients with session management.

#### Positional Argument Traps

Some library functions have positional arguments whose order cannot be inferred from the function name or the argument values themselves. Small models consistently get these wrong — not because they lack reasoning ability, but because the correct order isn't in their training data or is counterintuitive. When the model gets it wrong, the error appears at runtime (often as a confusing TypeError or silent data corruption), not at the point of writing the call. The model then exhausts its reflections guessing at fixes.

**Signal:** A function call where:
1. Two or more positional arguments have the same or similar types (both are strings, both are dicts, both are file-like objects)
2. The argument names don't appear at the call site (positional-only or positional-in-practice)
3. Swapping the arguments produces a plausible-looking but incorrect call

**Fix:** Mock the call in conftest so the model never writes it directly. The fixture captures what was passed so tests can assert on the arguments.

**Example — `fastavro.writer(fo, schema, records)`:**
The signature is `writer(fo, schema, records)` but models consistently write `writer(fo, records, schema)` or `writer(fo, records)`. Both are plausible from the name alone; the error only surfaces when fastavro tries to parse `records` as a schema dict. Rather than documenting the correct order in the task spec (which the model may not follow), mock fastavro in conftest:

```python
@pytest.fixture
def mock_fastavro_writer():
    """Patches fastavro.writer to avoid positional arg order errors.
    
    Captures (schema, records) passed to the call for test assertions.
    Usage:
        def test_write(mock_fastavro_writer):
            # ... call your writer
            schema, records = mock_fastavro_writer["last_call"]
            assert schema["type"] == "record"
    """
    with patch("plugins.writers.minio_writer.fastavro.writer") as mock_writer:
        state = {"last_call": None}

        def capture(fo, schema, records):
            state["last_call"] = (schema, records)

        mock_writer.side_effect = capture
        yield state
```

This pattern generalises to any library with the same signal: identify the trap during plan writing, create a fixture that captures the call, and let tests assert on what was passed rather than whether the call succeeded.

**Other examples of the same pattern** (not exhaustive — apply the signal check to any library in the plan):
- `struct.pack(fmt, *values)` — format string and values easy to swap
- `re.sub(pattern, repl, string)` — all strings, order non-obvious
- Some SQL driver `execute(query, params)` variants where param binding style differs by driver
- Serialization libraries that take `(output, schema, data)` or `(output, data, schema)` depending on version

### How to Create Them

Each fixture should:
1. Patch at the correct import boundary (where the implementation imports from)
2. Wire the full mock chain so the model doesn't need to understand library internals
3. Expose simple attributes for test customization (set return values, check call args)
4. Handle I/O simulation correctly (e.g., writing to BytesIO buffers during download mocks)
5. Clean up patches after the test

Use `@pytest.fixture` (not autouse — the model opts in by adding the fixture name to its test function signature). Return the mock object so tests can configure it.

### Example: Google Drive API v3

This is a representative example of the kind of fixture Claude Code should create. The Google Drive client has a fluent API chain and a buffer-based download loop — two things small models get wrong every time.

```python
@pytest.fixture
def mock_drive_service():
    """Pre-wired Google Drive API v3 mock.
    
    Usage in tests:
        def test_download(mock_drive_service):
            mock_drive_service["file_bytes"] = b"my content"
            # ... call your client, assert results
    
    Provides:
        mock_drive_service["service"]  - the mocked Drive service object
        mock_drive_service["file_bytes"] - set this to control download content (default: b"test data")
        mock_drive_service["file_list"] - set this to control files().list() results
    """
    with patch("plugins.writers.google_drive_client.build") as mock_build, \
         patch("plugins.writers.google_drive_client.Credentials") as mock_creds, \
         patch("plugins.writers.google_drive_client.MediaIoBaseDownload") as mock_download_cls:
        
        mock_service = MagicMock()
        mock_build.return_value = mock_service
        
        # State dict the test can customize
        state = {
            "service": mock_service,
            "file_bytes": b"test data",
            "file_list": [{"id": "file-123", "name": "test.zip"}],
        }
        
        # Wire files().list().execute() chain
        mock_service.files.return_value.list.return_value.execute.return_value = {
            "files": state["file_list"]
        }
        
        # Wire download to actually write bytes into the buffer
        def download_side_effect(fh, request):
            downloader = MagicMock()
            def next_chunk():
                fh.write(state["file_bytes"])
                return (MagicMock(progress=lambda: 1.0), True)
            downloader.next_chunk = next_chunk
            return downloader
        
        mock_download_cls.side_effect = download_side_effect
        
        yield state
```

### Example: boto3 S3 Client

```python
@pytest.fixture
def mock_s3_client():
    """Pre-wired boto3 S3 client mock with put_object capture.
    
    Usage in tests:
        def test_upload(mock_s3_client):
            # ... call your writer
            body = mock_s3_client["captured_body"]()  # get the uploaded bytes
    """
    with patch("plugins.writers.minio_writer.boto3.client") as mock_client_cls:
        mock_s3 = MagicMock()
        mock_client_cls.return_value = mock_s3
        
        state = {"client": mock_s3}
        
        # Capture put_object Body arg for assertions
        state["captured_body"] = lambda: mock_s3.put_object.call_args[1]["Body"]
        state["captured_key"] = lambda: mock_s3.put_object.call_args[1]["Key"]
        state["captured_bucket"] = lambda: mock_s3.put_object.call_args[1]["Bucket"]
        
        yield state
```

### Example: pika/RabbitMQ

```python
@pytest.fixture
def mock_pika_connection():
    """Pre-wired pika.BlockingConnection mock with channel and publish.
    
    Usage in tests:
        def test_publish(mock_pika_connection):
            # ... call your publisher
            call_args = mock_pika_connection["channel"].basic_publish.call_args
    """
    with patch("plugins.writers.rabbitmq_publisher.pika.BlockingConnection") as mock_conn_cls:
        mock_conn = MagicMock()
        mock_channel = MagicMock()
        mock_conn_cls.return_value = mock_conn
        mock_conn.channel.return_value = mock_channel
        
        state = {
            "connection_cls": mock_conn_cls,
            "connection": mock_conn,
            "channel": mock_channel,
        }
        
        yield state
```

### Listing Fixtures in the Project Context

After creating fixtures, list them in the project context block that gets embedded in every task doc. This is how the small model knows they exist. Format:

```
Available conftest fixtures (use these instead of writing your own mocks):
- `mock_drive_service` — pre-wired Google Drive API v3 mock with download support
- `mock_s3_client` — pre-wired boto3 S3 client mock with put_object capture
- `mock_pika_connection` — pre-wired pika.BlockingConnection mock with channel/publish
```

The names and one-line descriptions are enough — the model adds the fixture name to its test function parameters, pytest injects it, and the test can configure return values without touching mock internals.

### Verifying Fixtures

After creating conftest fixtures, write a minimal smoke test that imports and uses each one. This catches patch target path errors before the small model encounters them. A simple test per fixture:

```python
def test_mock_drive_service_fixture(mock_drive_service):
    assert mock_drive_service["file_bytes"] == b"test data"

def test_mock_s3_client_fixture(mock_s3_client):
    assert mock_s3_client["client"] is not None

def test_mock_pika_connection_fixture(mock_pika_connection):
    assert mock_pika_connection["channel"] is not None
```

Run `pytest` and verify these pass before generating task docs. If a patch target is wrong (e.g., the implementation file doesn't exist yet), adjust the patch path to match where the implementation will import from — the plan's "Files to Create" section tells you the exact module paths.

## Mutation Testing

Mutation testing verifies that tests actually catch bugs. A mutation tool makes small, deliberate code changes ("mutants") to a stub implementation and re-runs the tests. If a test passes with a mutated stub, it means the test wouldn't catch that class of bug in the real implementation — a weak assertion.

Run this during Step 3b before embedding tests in task docs. Target: ≥80% mutation score. Surviving mutants above that threshold require strengthening the corresponding tests.

**This step uses a stub implementation — not the final code.** The stub must be importable with correct signatures but no real logic. This is intentional: mutations are applied to the stub so you can detect whether tests are sensitive to logic changes.

### Python: mutmut

`mutmut` is the recommended Python mutation testing tool (v3.5.0, PyPI: `mutmut`, requires Python ≥3.10).

**Install:**
```bash
pip install mutmut
# or with uv:
uv add --dev mutmut
```

**Run against a specific module + test file:**
```bash
# From project/service root
mutmut run --paths-to-mutate src/mymodule/filter.py
# View surviving mutants
mutmut results
# Inspect a specific survivor
mutmut show <id>
```

**Configure in `pyproject.toml` or `setup.cfg`** (recommended for service directories):
```toml
[tool.mutmut]
paths_to_mutate = "src/mymodule/"
tests_dir = "tests/"
```

**Interpreting results:**
- `killed` — test caught the mutation. Good.
- `survived` — test passed despite the mutation. Weak assertion — strengthen the test.
- `suspicious` — test timed out or behaved unexpectedly. Investigate.
- `skipped` — mutmut couldn't apply the mutation (usually type annotation conflicts). Usually ignorable.

**Minimum threshold:** 80% killed. If score is below this, check `mutmut results` for survivors and add assertions that would catch them.

**Note on performance:** mutmut runs the full test suite once per mutant. For large test suites, scope it to just the test file for the task under review using `pytest_add_cli_args_test_selection` in config:
```toml
[tool.mutmut]
paths_to_mutate = "src/mymodule/filter.py"
pytest_add_cli_args_test_selection = "tests/test_filter.py"
```

### TypeScript/JavaScript: Stryker

For TypeScript and JavaScript projects, [Stryker Mutator](https://stryker-mutator.io/) is the equivalent tool.

**Install:**
```bash
npm install --save-dev @stryker-mutator/core @stryker-mutator/jest-runner
# or for Vitest:
npm install --save-dev @stryker-mutator/core @stryker-mutator/vitest-runner
```

**Run:**
```bash
npx stryker run
```

**Minimal config (`stryker.config.mjs`):**
```js
export default {
  testRunner: 'jest',  // or 'vitest'
  coverageAnalysis: 'perTest',
  mutate: ['src/mymodule/filter.ts'],
};
```

### Kotlin/Java: PIT (Pitest)

For JVM projects using Gradle, [Pitest](https://pitest.org/) is the standard mutation testing tool.

**Add to `build.gradle.kts`:**
```kotlin
plugins {
    id("info.solidsoft.pitest") version "1.15.0"
}
pitest {
    targetClasses.set(listOf("com.example.mymodule.*"))
    targetTests.set(listOf("com.example.mymodule.*Test"))
    mutationThreshold.set(80)
}
```

**Run:**
```bash
./gradlew pitest
```

### Rust: cargo-mutants

For Rust projects, [cargo-mutants](https://mutants.rs/) is the recommended tool.

**Install:**
```bash
cargo install cargo-mutants
```

**Run against a specific module:**
```bash
cargo mutants --file src/filter.rs
```

### Go: go-mutesting

For Go projects, [go-mutesting](https://github.com/zimmski/go-mutesting) is the most established option, though the ecosystem is less mature than Python/JS.

```bash
go install github.com/zimmski/go-mutesting/cmd/go-mutesting@latest
go-mutesting ./mypackage/...
```

### When Mutation Testing Isn't Available

If no mutation testing tool is available or practical for the language (e.g., shell scripts, SQL, config-heavy projects), apply the anti-patterns checklist from `writing-guide.md` § "Anti-Patterns to Avoid" manually as a code review step before embedding tests in task docs. Document that mutation testing was skipped and why in the manifest (`"mutation_gate": "skipped", "mutation_gate_reason": "..."`). This is an acceptable fallback — the anti-pattern review catches the most common failure modes even without automated tooling.

## Common Tooling by Language

| Language | Linter | Test Framework | Mutation Tool | Lint Wrapper Needed? |
|----------|--------|---------------|---------------|-----|
| Python | ruff | pytest | mutmut | Yes — use `scripts/lint-ruff-wrapper.sh` |
| Kotlin/Java | ktlint / Gradle | JUnit (via Gradle) | Pitest (Gradle plugin) | Probably not — Gradle tasks ignore non-source files |
| TypeScript | ESLint | Jest or Vitest | Stryker | Maybe — ESLint ignores non-JS files by default, but test if aider passes unexpected files |
| Rust | clippy | cargo test | cargo-mutants | No — clippy only processes .rs files |
| Go | golangci-lint | go test | go-mutesting | No — golangci-lint only processes .go files |

For languages not listed, check whether the linter handles non-source files gracefully when passed explicitly. If not, create a language-specific wrapper in `scripts/` following the pattern in `lint-ruff-wrapper.sh`.
