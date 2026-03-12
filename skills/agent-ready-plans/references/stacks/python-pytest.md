# Python + pytest Stack Reference

Read this file when:
- The project's language is Python and test framework is pytest
- Setting up tooling (SKILL.md Steps 2–3)
- Creating conftest fixtures (Step 3)
- Writing stubs for mutation testing (Step 3b)

---

## Package Manager Setup

Investigate first, then use the manager the project already uses.

**uv (preferred for new projects):**
```bash
cd services/my-service
uv init --python 3.11
uv add --dev ruff pytest mutmut
uv sync
uv run ruff check .
uv run pytest tests/ -v
```

**pip + venv:**
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pip install ruff pytest mutmut
```

**poetry:**
```bash
poetry add --group dev ruff pytest mutmut
poetry install
```

---

## Lint Wrapper (required for ruff + aider)

Ruff always lints files passed explicitly on the command line — including non-Python files like `requirements.txt`, `Dockerfile`, `.gitkeep` that aider may have edited alongside `.py` files. Ruff reports syntax errors on these that the small model can never fix, causing an infinite retry loop.

The reliable fix is the lint wrapper at `scripts/lint-ruff-wrapper.sh`. It:
1. Filters out non-Python files before passing them to ruff
2. Runs ruff with `--fix` so trivially fixable issues (import sorting, unused imports) are auto-corrected

**Setup:**
```bash
cp scripts/lint-ruff-wrapper.sh docs/plans/my-tasks/lint.sh
chmod +x docs/plans/my-tasks/lint.sh
```

Update `RUFF_BIN` in the script to match the project's ruff binary:
```bash
# Single project, ruff on PATH:
RUFF_BIN="ruff"

# Monorepo with venv:
RUFF_BIN="services/my-service/.venv/bin/ruff"

# Monorepo with uv:
RUFF_BIN="uv run --project services/my-service ruff"
```

Test it:
```bash
./docs/plans/my-tasks/lint.sh services/foo/bar.py services/foo/requirements.txt
# Should only lint bar.py, skip requirements.txt
```

**Manifest lint_cmd always points to the wrapper:**
```json
{
  "tooling": {
    "lint_cmd": "./docs/plans/my-tasks/lint.sh",
    "test_cmd": "cd services/my-service && uv run pytest -x -q"
  }
}
```

Do NOT use `cd` in `lint_cmd` — aider appends file paths relative to the project root, which break after a directory change. `cd` is safe in `test_cmd` only.

---

## Stub Design

```python
class RecordFilter:
    def filter(self, rows: list[Row], watermark: int) -> list[Row]:
        raise NotImplementedError

    def count(self, rows: list[Row]) -> int:
        raise NotImplementedError
```

**Module-level singletons must not be instantiated in stubs.** If a module defines a singleton (e.g., `settings = Settings()`), and other stubs import it at the top level, the constructor runs at pytest collection time. If it requires env vars, files, or network, collection fails for every transitively-importing test file — not as a test failure, but as a collection error that blocks Layer 2 validation entirely.

```python
# WRONG stub — Settings() requires env vars; fails at collection
settings = Settings()

# CORRECT stub — importable without env vars
settings = None
```

The real `settings = Settings()` belongs only in the final implementation task.

---

## Mocking Framework Modules

When a framework (e.g. Airflow, Django, Flask, Celery) is not installed in the dev environment, stub every anticipated import path in `sys.modules` at conftest import time:

```python
# conftest.py — executes before any test collection
import sys
from unittest.mock import MagicMock

_FRAMEWORK_MOCKS = [
    "airflow",
    "airflow.models",
    "airflow.operators",
    "airflow.operators.python",
    "airflow.utils",
    "airflow.utils.task_group",   # must register EVERY dotted path used in imports
]
for _mod in _FRAMEWORK_MOCKS:
    if _mod not in sys.modules:
        sys.modules[_mod] = MagicMock()
```

**Critical rule:** `airflow.utils` and `airflow.utils.task_group` are separate entries. If only `airflow.utils` is registered, Python sees it as a `MagicMock` object (not a package) and raises:
```
ModuleNotFoundError: No module named 'airflow.utils.task_group'; 'airflow.utils' is not a package
```

Mental model: for any import path `a.b.c`, register `a`, `a.b`, and `a.b.c` separately.

**Verification step — run before generating any task docs:**
```bash
python -c "import conftest; from plugins.my_module import MyClass"
```
This catches missing submodule entries immediately, before the small model ever sees them.

---

## External Dependency Mock Fixtures

### Google Drive API v3

```python
@pytest.fixture
def mock_drive_service():
    """Pre-wired Google Drive API v3 mock.

    Usage:
        def test_download(mock_drive_service):
            mock_drive_service["file_bytes"] = b"my content"
            # call your client, assert results

    Provides:
        ["service"]    — the mocked Drive service object
        ["file_bytes"] — set to control download content (default: b"test data")
        ["file_list"]  — set to control files().list() results
    """
    with patch("plugins.clients.google_drive_client.build") as mock_build, \
         patch("plugins.clients.google_drive_client.Credentials") as mock_creds, \
         patch("plugins.clients.google_drive_client.MediaIoBaseDownload") as mock_dl_cls:

        mock_service = MagicMock()
        mock_build.return_value = mock_service

        state = {
            "service": mock_service,
            "file_bytes": b"test data",
            "file_list": [{"id": "file-123", "name": "test.zip"}],
        }

        mock_service.files.return_value.list.return_value.execute.return_value = {
            "files": state["file_list"]
        }

        def download_side_effect(fh, request):
            downloader = MagicMock()
            def next_chunk():
                fh.write(state["file_bytes"])
                return (MagicMock(progress=lambda: 1.0), True)
            downloader.next_chunk = next_chunk
            return downloader

        mock_dl_cls.side_effect = download_side_effect
        yield state
```

### boto3 S3 / MinIO

```python
@pytest.fixture
def mock_s3_client():
    """Pre-wired boto3 S3 client mock with put_object capture.

    Usage:
        def test_upload(mock_s3_client):
            body = mock_s3_client["captured_body"]()
    """
    with patch("plugins.writers.minio_writer.boto3.client") as mock_client_cls:
        mock_s3 = MagicMock()
        mock_client_cls.return_value = mock_s3

        yield {
            "client": mock_s3,
            "captured_body":   lambda: mock_s3.put_object.call_args[1]["Body"],
            "captured_key":    lambda: mock_s3.put_object.call_args[1]["Key"],
            "captured_bucket": lambda: mock_s3.put_object.call_args[1]["Bucket"],
        }
```

### pika / RabbitMQ

```python
@pytest.fixture
def mock_pika_connection():
    """Pre-wired pika.BlockingConnection mock.

    Usage:
        def test_publish(mock_pika_connection):
            call_args = mock_pika_connection["channel"].basic_publish.call_args
    """
    with patch("plugins.writers.rabbitmq_publisher.pika.BlockingConnection") as mock_conn_cls:
        mock_conn = MagicMock()
        mock_channel = MagicMock()
        mock_conn_cls.return_value = mock_conn
        mock_conn.channel.return_value = mock_channel

        yield {
            "connection_cls": mock_conn_cls,
            "connection": mock_conn,
            "channel": mock_channel,
        }
```

### Positional Argument Trap — fastavro

`fastavro.writer(fo, schema, records)` — models consistently swap args 2 and 3. Both orderings look plausible; the error only surfaces at runtime when fastavro tries to parse `records` as a schema dict.

```python
@pytest.fixture
def mock_fastavro_writer():
    """Patches fastavro.writer to avoid positional arg order errors.

    Captures (schema, records) for test assertions.
    Usage:
        def test_write(mock_fastavro_writer):
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

Apply the same fixture-capture pattern to any library with the positional trap signal (see `tooling.md` § "Positional Argument Traps").

---

## Mutation Testing — mutmut

```bash
pip install mutmut   # or: uv add --dev mutmut
```

**Run against a specific module:**
```bash
mutmut run --paths-to-mutate src/mymodule/filter.py
mutmut results        # view surviving mutants
mutmut show <id>      # inspect a specific survivor
```

**Scope to a single test file in pyproject.toml:**
```toml
[tool.mutmut]
paths_to_mutate = "src/mymodule/filter.py"
pytest_add_cli_args_test_selection = "tests/test_filter.py"
```

**Results:**
- `killed` — test caught the mutation. Good.
- `survived` — weak assertion. Strengthen the test.
- `suspicious` — timed out. Investigate.
- `skipped` — mutation couldn't be applied (often type annotation conflicts). Usually ignorable.

Target: ≥80% killed before embedding tests in task docs.

---

## Persistence Class Stubs (SQLite example)

When writing the mutation-gate stub for a persistence class, deliberately omit schema initialization from `__init__`:

```python
# CORRECT mutation-gate stub — forces tests to catch missing CREATE TABLE
class UUIDStore:
    def __init__(self, db_path: str):
        pass  # deliberately empty — real __init__ must call _init_schema()

    def mark_seen(self, ids: list[str]) -> None:
        raise NotImplementedError
```

Add a test that exercises a schema-dependent method immediately after construction:

```python
def test_schema_initialized_on_construction(tmp_path):
    store = UUIDStore(str(tmp_path / "test.db"))
    store.mark_seen(["id-1"])  # must not raise "no such table"
```

---

## SQLite Trap Patterns

Two SQLite traps consistently break small model implementations. Document both in every task doc's `## Behavior` section whenever SQLite is used.

### Trap 1 — `:memory:` multi-connection

Each `sqlite3.connect(":memory:")` creates a completely independent in-memory database. If the implementation opens a fresh connection per method call, `_init_schema()` creates the table in one DB and the next method call opens a fresh empty one — `no such table`.

Fix: hold a persistent connection for the object's lifetime:

```python
class UUIDStore:
    def __init__(self, db_path: str):
        self._conn = sqlite3.connect(db_path)  # persistent — same DB for all methods
        self._init_schema()
```

Task doc Behavior entry: *"Must hold a persistent `self._conn` connection opened in `__init__` — do not open a new connection per method call."*

### Trap 2 — Multi-column row-value constructor in IN clause

SQLite does not support multi-column row-value constructors in `IN` clauses. The following raises `OperationalError: IN(...) element has 1 term - expected 2`:

```python
# WRONG — SQLite does not support this syntax
cursor = conn.execute(
    "SELECT uuid_hex FROM t WHERE (uuid_hex, record_type) IN (?, ?, ?, ?)",
    [*interleaved_params]
)
```

Small models consistently attempt this pattern when filtering on two columns simultaneously. Every reflection tries a variation of the same approach and never escapes. The correct pattern is a single-column `IN` with an `AND` clause for the second filter:

```python
# CORRECT — single-column IN + AND for the second filter
placeholders = ','.join('?' * len(uuids))
query = (
    f"SELECT uuid_hex FROM seen_uuids "
    f"WHERE uuid_hex IN ({placeholders}) AND record_type = ?"
)
cursor = conn.execute(query, [*uuids, record_type])
```

Task doc Behavior entry: *"SQLite does not support multi-column IN clauses — use `WHERE col1 IN (?, ...) AND col2 = ?` with params `[*col1_values, col2_value]`."*

Include this note in the task doc whenever a query filters on two or more columns using `IN`.
