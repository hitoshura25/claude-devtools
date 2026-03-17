# Fixture Patterns for Python + pytest

Read this file when writing conftest fixtures (SKILL.md Step 3) and test files (Step 3b).

Every mock fixture falls into one of three behavioral patterns. The pattern determines
what tests using that fixture can and cannot assert on. Getting this wrong produces tests
that are logically impossible to pass — the mock prevents the behavior the test asserts on,
and the small model exhausts all reflections on an unfixable contradiction.

**Copy the fixture template for the appropriate pattern.** Adjust the patch path and
field names for the specific technology. Do not restructure the fixture or change its
behavioral contract — the usage rules depend on it.

---

## Pattern 1: Capture Mock

**Purpose:** Replace a function that transforms or serializes data. Capture the arguments
for assertion, but do NOT reproduce the function's output side effects.

**What tests CAN assert:** which args were passed (schema, records, format, etc.)
**What tests CANNOT assert:** the output the original function would have produced
(bytes written to a buffer, return values, file contents)

**When to use:** Serializers (`fastavro.writer`, `json.dumps` wrappers, `csv.writer`),
formatters, encoders — any function where the model is likely to swap argument order
and you want to verify the correct args were passed.

### Template

```python
@pytest.fixture
def mock_<library>_<function>():
    """Capture mock for <library>.<function>.

    Captures call arguments for assertion. Does NOT reproduce the original
    function's side effects (e.g., does not write bytes to a file handle).

    Usage rules:
        ✅ Assert on captured args:
            schema, records = mock_fixture["last_call"]
            assert schema["name"] == "MyRecord"
        ❌ Do NOT assert on output side effects (buffer contents, return values):
            body = get_body_from_downstream()
            assert len(body) > 0  # WILL FAIL — mock doesn't write to buffer
    """
    with patch("<module.path.to.function>") as mock_fn:
        state: dict = {"last_call": None, "call_count": 0}

        def _capture(*args, **kwargs):
            state["call_count"] += 1
            state["last_call"] = args
            # If downstream code needs a return value, provide a sensible default:
            # return b"" or return None

        mock_fn.side_effect = _capture
        yield state
```

### Example: fastavro.writer

`fastavro.writer(fo, schema, records)` — models consistently swap args 2 and 3.

```python
@pytest.fixture
def mock_fastavro_writer():
    """Capture mock for fastavro.writer — captures (schema, records).

    Does NOT write bytes to the file handle. Tests using this fixture
    must NOT assert on the Avro byte output (buffer contents, Body size).
    To test byte output, omit this fixture and let real fastavro run.
    """
    with patch("<service>.writers.<module>.fastavro.writer") as mock_writer:
        state: dict = {"last_call": None}

        def _capture(fo, schema, records):
            state["last_call"] = (schema, list(records))

        mock_writer.side_effect = _capture
        yield state
```

**Patch path:** Replace `<service>.writers.<module>` with the actual module path.

---

## Pattern 2: Client Mock

**Purpose:** Replace a client constructor so no real connections are made. The client
itself is a MagicMock — all method calls are recorded and can be asserted on.

**What tests CAN assert:** which methods were called, with what kwargs, how many times
**What tests CANNOT assert:** return values from the real service (unless you set
`return_value` on specific methods)

**When to use:** HTTP clients (`boto3.client`, `httpx.Client`), database connections
(`psycopg2.connect`), message broker connections (`pika.BlockingConnection`),
API clients (`build` for Google APIs).

### Template

```python
@pytest.fixture
def mock_<service>_client():
    """Client mock for <service> — records all method calls.

    Usage rules:
        ✅ Assert on call patterns:
            assert mock_fixture["client"].put_object.called
            assert mock_fixture["captured_key"]() == "expected/path"
        ✅ Assert on kwargs:
            call_kwargs = mock_fixture["client"].method.call_args[1]
        ❌ Do NOT assert on return values unless you explicitly set them:
            result = mock_fixture["client"].get_object()  # returns MagicMock, not real data
    """
    with patch("<module.path.to.constructor>") as mock_cls:
        mock_instance = MagicMock()
        mock_cls.return_value = mock_instance

        yield {
            "client": mock_instance,
            # Add convenience accessors for commonly-asserted kwargs:
            # "captured_<kwarg>": lambda: mock_instance.<method>.call_args[1]["<kwarg>"],
        }
```

### Example: boto3 S3 / MinIO

```python
@pytest.fixture
def mock_s3_client():
    """Client mock for boto3 S3 — captures put_object kwargs."""
    with patch("<service>.writers.<module>.boto3.client") as mock_cls:
        mock_s3 = MagicMock()
        mock_cls.return_value = mock_s3

        yield {
            "client": mock_s3,
            "captured_body":   lambda: mock_s3.put_object.call_args[1]["Body"],
            "captured_key":    lambda: mock_s3.put_object.call_args[1]["Key"],
            "captured_bucket": lambda: mock_s3.put_object.call_args[1]["Bucket"],
        }
```

### Example: pika / RabbitMQ

```python
@pytest.fixture
def mock_pika_connection():
    """Client mock for pika.BlockingConnection.

    NOTE: is_closed is explicitly set to False. MagicMock attributes are
    truthy by default, which breaks `if not conn.is_closed:` guards.
    """
    with patch("<service>.writers.<module>.pika.BlockingConnection") as mock_cls:
        mock_conn = MagicMock()
        mock_conn.is_closed = False  # explicit — see Pika Connection Lifecycle Trap
        mock_channel = MagicMock()
        mock_cls.return_value = mock_conn
        mock_conn.channel.return_value = mock_channel

        yield {
            "connection_cls": mock_cls,
            "connection": mock_conn,
            "channel": mock_channel,
        }
```

### Example: Google Drive API

```python
@pytest.fixture
def mock_drive_service():
    """Client mock for Google Drive API v3 with download simulation.

    Set state["file_bytes"] to control what the download produces.
    Set state["file_list"] to control what files().list() returns.
    """
    build_path = "<service>.writers.<module>.build"
    creds_path = "<service>.writers.<module>.Credentials"
    dl_path = "<service>.writers.<module>.MediaIoBaseDownload"

    with (
        patch(build_path) as mock_build,
        patch(creds_path),
        patch(dl_path) as mock_dl_cls,
    ):
        mock_service = MagicMock()
        mock_build.return_value = mock_service

        state: dict = {
            "service": mock_service,
            "file_bytes": b"test data",
            "file_list": [{"id": "file-123", "name": "test.zip"}],
        }

        (
            mock_service.files.return_value
            .list.return_value
            .execute.return_value
        ) = {"files": state["file_list"]}

        def _download_side_effect(fh, _request):
            downloader = MagicMock()

            def _next_chunk():
                fh.write(state["file_bytes"])
                return (MagicMock(progress=lambda: 1.0), True)

            downloader.next_chunk = _next_chunk
            return downloader

        mock_dl_cls.side_effect = _download_side_effect
        yield state
```

**Patch paths:** Replace `<service>.writers.<module>` with the actual module path.

---

## Pattern 3: Stateful Fake

**Purpose:** Replace a backend with a real, in-process implementation. The fake
has real behavior — operations actually persist, queries actually return data.

**What tests CAN assert:** actual outcomes (data persisted, queries return correct results)
**What tests CANNOT assume:** identical behavior to the real backend in all edge cases

**When to use:** In-memory databases (`:memory:` SQLite), in-memory caches, fake
file systems, test doubles with real logic.

### Template

```python
@pytest.fixture
def <component>(tmp_path):
    """Real <Component> backed by a temp-file store.

    Uses tmp_path (not :memory:) to avoid the multi-connection trap:
    each sqlite3.connect(":memory:") creates an independent database.

    If :memory: is needed for speed, the implementation MUST hold a
    persistent self._conn — see python-pytest.md § "SQLite Trap Patterns".
    """
    instance = Component(str(tmp_path / "test.db"))
    yield instance
    # Teardown — close connections if the component holds any
    if hasattr(instance, "_conn"):
        instance._conn.close()
```

### Rules for stateful fakes

- **Prefer `tmp_path` over `:memory:`** for SQLite-backed components. File-backed
  databases work correctly even if the implementation opens separate connections per
  method. `:memory:` databases require a persistent connection — if you use `:memory:`,
  the task doc's Behavior section MUST include the persistent connection instruction.
- **Tear down resources** in the fixture (close connections, delete temp files).
- **Do not share stateful fakes across tests** — each test gets a fresh instance.

---

## Fixture Interaction Rules

These rules prevent logically impossible tests — where a mock prevents the behavior
the test asserts on. Claude Code must follow these when writing test files in Step 3b.

### Rule 1: Capture mocks block downstream side effects

When a test uses a **capture mock** (Pattern 1), the original function's side effects
do not occur. Do not assert on those side effects in the same test.

```python
# WRONG — mock_fastavro_writer captures args but doesn't write bytes to buffer.
# The Body will be empty (b""), and this assertion will always fail.
def test_body_non_empty(mock_s3_client, mock_fastavro_writer):
    writer.upload_avro(records, schema, ...)
    body = mock_s3_client["captured_body"]()
    assert len(body) > 0  # ❌ always fails — mock didn't write to buffer

# CORRECT — split into two tests:
# Test 1: verify correct args using capture mock
def test_avro_schema_correct(mock_s3_client, mock_fastavro_writer):
    writer.upload_avro(records, schema, ...)
    captured_schema, captured_records = mock_fastavro_writer["last_call"]
    assert captured_schema["name"] == "TestRecord"
    assert len(captured_records) == 2

# Test 2: verify non-empty output WITHOUT capture mock (let real library run)
def test_avro_body_non_empty(mock_s3_client):
    writer.upload_avro(records, schema, ...)
    body = mock_s3_client["captured_body"]()
    assert len(body) > 0  # ✅ real fastavro.writer runs, buffer has bytes
```

### Rule 2: Client mocks return MagicMocks, not real data

When a test uses a **client mock** (Pattern 2), method return values are MagicMocks
unless explicitly set. Do not assert on return values without setting them first.

### Rule 3: Stateful fakes have real constraints

When a test uses a **stateful fake** (Pattern 3), the fake's constraints apply.
For `:memory:` SQLite: each new connection is a separate database. For `tmp_path`
SQLite: the file persists across connections within the same test.

---

## How to Use This File

**During Step 3 (conftest setup):**
1. Identify which external dependencies the project mocks
2. For each, pick the appropriate pattern (capture, client, or stateful)
3. Copy the template, replace `<service>.writers.<module>` with the actual patch path
4. Add to conftest.py

**During Step 3b (test writing):**
1. Before writing a test that uses multiple fixtures, check the interaction rules above
2. If a test needs to assert on output bytes/contents AND verify correct args,
   split it into two tests: one with the capture mock, one without
3. Never combine a capture mock with an assertion on the captured function's output

**During Step 5 (task doc generation):**
1. List available fixtures in the Project Context block
2. Include the fixture's pattern type (capture/client/stateful) so the small model
   knows what it can and cannot assert on — though the small model should never need
   to modify test files
