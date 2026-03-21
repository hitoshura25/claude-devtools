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

## Ruff Configuration (pyproject.toml)

The canonical ruff config for a new service:

```toml
[tool.ruff]
target-version = "py311"
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I", "W"]
```

**Critical: do NOT add `E501` to `ignore`.** E501 is the line-length rule. Suppressing it
globally defeats the purpose of the lint gate — the small model will write arbitrarily long
lines and the linter will never fire. If E501 violations appear in test files or conftest
during Step 3b, fix the lines (break them, use multi-line strings, extract constants) rather
than suppressing the rule. The SQL Constants Pattern and the wiring task callable-body
snippet rules exist precisely to prevent long-line violations at the source. Suppressing
E501 is never the right fix.

```toml
# CORRECT
[tool.ruff.lint]
select = ["E", "F", "I", "W"]

# WRONG — suppresses line-length enforcement, defeats lint gate
[tool.ruff.lint]
select = ["E", "F", "I", "W"]
ignore = ["E501"]
```

If the project already has `ignore = ["E501"]` (e.g. from a previous run where it was
added as a workaround), remove it before proceeding.

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

## SQL Constants Pattern

**Never inline SQL strings as method-body literals.** SQL strings embedded directly in method bodies are prone to E501 lint violations (SQL reads naturally as a long single line, but Python enforces an 88-char limit). Multi-line string concatenation within a method body is hard to read and still fragile. Small models consistently write SQL as single-line literals; the linter fires; reflections are consumed on formatting rather than logic.

The correct Python idiom is to assign SQL strings to named module-level constants:

```python
# CORRECT — module-level constant, never fires E501 in method bodies
_INIT_SCHEMA_SQL = """
    CREATE TABLE IF NOT EXISTS seen_uuids (
        uuid_hex TEXT NOT NULL,
        record_type TEXT NOT NULL,
        seen_at TEXT NOT NULL,
        PRIMARY KEY (uuid_hex, record_type)
    )
"""

_MARK_SEEN_SQL = (
    "INSERT OR IGNORE INTO seen_uuids "
    "(uuid_hex, record_type, seen_at) VALUES (?, ?, ?)"
)

_FILTER_SEEN_SQL_TEMPLATE = (
    "SELECT uuid_hex FROM seen_uuids "
    "WHERE uuid_hex IN ({placeholders}) AND record_type = ?"
)
```

Method bodies then reference the constant:

```python
def _init_schema(self) -> None:
    self._conn.execute(_INIT_SCHEMA_SQL)
    self._conn.commit()

def mark_seen(self, ids: list[str], record_type: str) -> None:
    now = datetime.utcnow().isoformat()
    self._conn.executemany(
        _MARK_SEEN_SQL,
        [(id_, record_type, now) for id_ in ids],
    )
    self._conn.commit()
```

**Apply this rule in task doc Behavior sections whenever SQL is used.** Instead of showing the SQL inline in a behavior bullet, show the constant name and its value as a module-level assignment. The small model will place it at module level where the linter never fires.

**Task doc Behavior entry example:**
```
- Define module-level SQL constants for all queries (do not inline SQL in method bodies):
    _MARK_SEEN_SQL = (
        "INSERT OR IGNORE INTO seen_uuids "
        "(uuid_hex, record_type, seen_at) VALUES (?, ?, ?)"
    )
- Use the constant in mark_seen() — do not write the SQL literal inside the method.
```

This rule is also why Claude Code must assign SQL to constants during Step 3b test writing — if the test fixture or conftest contains inline SQL, it will fire E501 and block the small model before it can even start.

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

Read `references/stacks/python-pytest/fixture-patterns.md` for the complete fixture template system.

Fixtures are categorized by **behavioral pattern**, not by technology. This matters
because each pattern has different rules about what tests can and cannot assert:

| Pattern | Purpose | Tests CAN assert | Tests CANNOT assert |
|---------|---------|-------------------|---------------------|
| **Capture mock** | Replace a function, capture its args | What args were passed | Output the original function would produce |
| **Client mock** | Replace a constructor, record method calls | Which methods called, with what kwargs | Return values (unless explicitly set) |
| **Stateful fake** | Real logic on a fake backend | Actual outcomes | Identical edge-case behavior to production |

The most critical rule: **when a test uses a capture mock, do not assert on side effects
the captured function would have produced.** This is the #1 source of logically impossible
tests — the mock prevents the behavior the assertion checks, and the small model exhausts
all reflections on an unfixable contradiction.

**During Step 3 (conftest setup):**
1. Read `python-pytest/fixture-patterns.md`
2. For each external dependency, pick the appropriate pattern
3. Copy the template, replace the patch paths for the project's module structure

**During Step 3b (test writing):**
1. Before combining multiple fixtures in one test, check the interaction rules in `python-pytest/fixture-patterns.md` § "Fixture Interaction Rules"
2. If a test needs to assert on output bytes AND verify correct args, split into two tests

### Technology-Specific Traps

These traps apply regardless of which fixture pattern is used. They are about specific
library/mock behaviors that consistently break small models.

#### Pika Connection Lifecycle Trap

Small models write a defensive `is_closed` guard when closing a pika connection:

```python
# WRONG — is_closed on a MagicMock is a MagicMock (truthy)
# so `not connection.is_closed` evaluates to False and close() is never called
finally:
    if connection and not connection.is_closed:
        connection.close()
```

**Fix in the fixture:** The pika client mock template in `python-pytest/fixture-patterns.md` sets
`mock_conn.is_closed = False` explicitly. This makes the guard evaluate correctly even
if the model writes it.

**Fix in task docs:** The Behavior section for any RabbitMQ publisher must show the
`finally` block as a code snippet using the unconditional form:

```python
# CORRECT — unconditional close; works with both real pika and mock
finally:
    if connection is not None:
        connection.close()
```

Task doc Behavior entry:
```
- Close the connection in a `finally` block using:
      finally:
          if connection is not None:
              connection.close()
  Do NOT guard with `connection.is_closed` — this attribute is truthy on MagicMock
  and will prevent close() from being called in tests.
```

#### Positional Argument Trap — fastavro

`fastavro.writer(fo, schema, records)` — models consistently swap args 2 and 3. The
capture mock template in `python-pytest/fixture-patterns.md` handles this by capturing the args for
assertion. Apply the same capture-mock pattern to any library where positional argument
order is ambiguous (see `tooling.md` § "Positional Argument Traps").

#### Avro Named Type Redefinition Trap — fastavro

`fastavro.parse_schema` rejects schemas that define the same named record type more
than once. This consistently traps small models when multiple fields share a nested
record structure (e.g., `startTime` and `endTime` both containing an `epochMillis`
field). The model defines the named type inline on both fields; fastavro raises:
```
SchemaParseException: redefined named type: <TypeName>
```

The correct Avro pattern is to define the named type inline on its *first* use,
then reference it by name string on all subsequent uses:

```python
# WRONG — defines "Timestamp" twice, fastavro rejects it
avro_schema = {
    "type": "record",
    "name": "MyRecord",
    "fields": [
        {"name": "startTime", "type": {
            "type": "record", "name": "Timestamp",
            "fields": [{"name": "epochMillis", "type": "long"}]
        }},
        {"name": "endTime", "type": {
            "type": "record", "name": "Timestamp",
            "fields": [{"name": "epochMillis", "type": "long"}]
        }},
    ],
}

# CORRECT — define inline first, then reference by name string
avro_schema = {
    "type": "record",
    "name": "MyRecord",
    "fields": [
        {"name": "startTime", "type": {
            "type": "record", "name": "Timestamp",
            "fields": [{"name": "epochMillis", "type": "long"}]
        }},
        {"name": "endTime", "type": "Timestamp"},
    ],
}
```

Small models cannot diagnose this error — every reflection re-attempts the same
duplicate definition pattern. The planning model must construct and validate
the exact schema against `fastavro.parse_schema` during Step 3b, then include
it verbatim in the task doc's Behavior section. This is an instance of the
general rule in `writing-guide.md`: "Include validated schemas in Behavior
sections when tests check schema parsing."

#### sys.modules Mock Constructor Trap

When a framework class is loaded from a `sys.modules` MagicMock entry (see
§ "Mocking Framework Modules" above), **constructor kwargs are silently discarded**.
Calling `FrameworkClass(name="my_thing", enabled=False)` returns a new MagicMock
whose `.name` and `.enabled` attributes are auto-generated MagicMocks — not the
string and bool that were passed in. This is fundamental to how MagicMock works:
`__call__` on a MagicMock records the call but does not wire kwargs onto the return
value as attributes.

This trap fires whenever:
1. The framework is not installed (mocked via `sys.modules`)
2. Code constructs a framework object with kwargs: `obj = FrameworkClass(attr="value")`
3. Tests assert on those attributes: `assert obj.attr == "value"`

The assertion fails because `obj.attr` is a MagicMock, not `"value"`.

Small models cannot reason their way out of this. They see the correct constructor
call, see the assertion fail, and spend all reflections trying aliases, re-imports,
or `__all__` declarations — none of which address the root cause.

**Fix in task docs (Step 5):** When a task constructs an object from a
`sys.modules`-mocked class and tests assert on its attributes, the Behavior section
must include explicit attribute assignments after the constructor. Show both the
constructor AND the assignments as a single code block so the model copies them
together:

```python
# Generic pattern — framework class loaded from sys.modules mock
obj = FrameworkClass(
    name="my_thing",
    schedule="0 */6 * * *",
    enabled=False,
)
# Required when framework is mocked via sys.modules:
# MagicMock constructors discard kwargs — assign attributes explicitly
# so tests asserting obj.name, obj.schedule, obj.enabled see real values.
obj.name = "my_thing"
obj.schedule = "0 */6 * * *"
obj.enabled = False
```

Task doc Behavior entry:
```
- After constructing the framework object, explicitly assign every attribute
  that tests will assert on. MagicMock constructors discard kwargs:
      obj = FrameworkClass(name="my_thing", schedule="0 */6 * * *")
      obj.name = "my_thing"
      obj.schedule = "0 */6 * * *"
  Without the explicit assignments, tests see MagicMock objects instead
  of the expected values.
```

**Checkpoint for Claude Code (Step 3b / Step 5):** For every wiring task that
constructs an object from a `sys.modules`-mocked framework, verify: does any test
assert on an attribute of that object? If yes, the task doc MUST include explicit
attribute assignments. This check applies to any framework mocked via `sys.modules`
— orchestrators, task schedulers, web framework route decorators, ORM model
definitions, etc.

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
def test_schema_initialized_on_construction():
    store = UUIDStore(":memory:")
    store.mark_seen(["id-1"])  # must not raise "no such table"
```

---

## SQLite Trap Patterns

Two SQLite traps consistently break small model implementations. Document both in every task doc's `## Behavior` section whenever SQLite is used.

### Trap 1 — `:memory:` multi-connection

Each `sqlite3.connect(":memory:")` creates a completely independent in-memory database. If the implementation opens a fresh connection per method call, `_init_schema()` creates the table in one DB and the next method call opens a fresh empty one — `no such table`.

**`:memory:` is the quality standard for SQLite test fixtures.** It is faster than file-backed (no disk I/O), provides perfect test isolation, and — critically — enforces correct implementation. A class that opens a new connection per method is genuinely wrong: it's slower in production, breaks transaction semantics across methods, and prevents WAL mode. The `:memory:` fixture catches this deficiency immediately rather than masking it.

The correct implementation pattern:

```python
class UUIDStore:
    def __init__(self, db_path: str):
        self._conn = sqlite3.connect(db_path)  # persistent — same DB for all methods
        self._init_schema()
```

**Do not use `tmp_path` for SQLite fixtures.** File-backed databases tolerate the multi-connection pattern (each `connect()` opens the same file), which masks the implementation bug. The tests pass but the code is wrong. The `:memory:` fixture is the enforcement mechanism — it makes the wrong pattern fail immediately.

Task doc Behavior entry: *"Must hold a persistent `self._conn` connection opened in `__init__` — do not open a new connection per method call."*

The fixture template in `python-pytest/fixture-patterns.md` Pattern 3 (Stateful Fake) uses `:memory:` by default. Copy it as-is.

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

**Note:** the query string above should be assigned to a module-level constant per the SQL Constants Pattern above — do not inline it in the method body.

---

## Wiring Task Patterns (Python-specific)

These patterns supplement the language-neutral wiring rules in `references/writing-guide.md`.

### Import Integrity Test

Every Python wiring task must include an `import_integrity` test that imports every
class the wiring task uses and asserts each is not None. This is the Python
implementation of the language-neutral rule in `writing-guide.md` § "Wiring Task Tests".

**Test pattern:**

```python
from mypackage.components.widget import Widget
from mypackage.components.gadget import Gadget
# ... one import per component the wiring task references

def test_import_integrity():
    assert Widget is not None
    assert Gadget is not None
```

**Layer 2 verification command:**

```bash
cd services/my-service && python -m pytest tests/test_orchestrator.py::test_import_integrity -x -q
```

If any import fails, a component task drifted — fix it before proceeding.
