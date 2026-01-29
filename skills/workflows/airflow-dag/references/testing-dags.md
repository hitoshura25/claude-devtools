# Testing Airflow DAGs

## DagBag Test

Test that all DAGs load without errors:

```python
# tests/test_dags.py
import pytest
from airflow.models import DagBag

@pytest.fixture
def dagbag():
    return DagBag(dag_folder='dags/', include_examples=False)

def test_dagbag_import(dagbag):
    """Test that all DAGs can be imported without errors."""
    assert dagbag.import_errors == {}, f"DAG import errors: {dagbag.import_errors}"

def test_dagbag_not_empty(dagbag):
    """Test that at least one DAG is loaded."""
    assert len(dagbag.dags) > 0, "No DAGs found"

def test_dag_tags(dagbag):
    """Test that all DAGs have tags."""
    for dag_id, dag in dagbag.dags.items():
        assert dag.tags, f"DAG {dag_id} has no tags"
```

## Individual DAG Tests

```python
# tests/test_health_connect_etl.py
import pytest
from datetime import datetime
from airflow.models import DagBag

@pytest.fixture
def dag():
    dagbag = DagBag(dag_folder='dags/', include_examples=False)
    return dagbag.get_dag('health_connect_etl')

def test_dag_loaded(dag):
    """Test that DAG is loaded."""
    assert dag is not None
    assert dag.dag_id == 'health_connect_etl'

def test_dag_schedule(dag):
    """Test DAG schedule interval."""
    assert dag.schedule_interval == '@daily'

def test_dag_default_args(dag):
    """Test default arguments."""
    assert dag.default_args.get('retries', 0) >= 1

def test_task_count(dag):
    """Test expected number of tasks."""
    assert len(dag.tasks) == 4

def test_task_dependencies(dag):
    """Test task dependencies are correct."""
    task_ids = [t.task_id for t in dag.tasks]
    assert 'pull_from_google_drive' in task_ids
    assert 'extract_sqlite' in task_ids
    assert 'transform_glucose' in task_ids
    assert 'load_to_postgres' in task_ids

    # Check dependencies
    extract = dag.get_task('extract_sqlite')
    assert 'pull_from_google_drive' in [t.task_id for t in extract.upstream_list]
```

## Task Logic Tests

Test task functions in isolation:

```python
# tests/test_transforms.py
import pytest
from dags.health_connect_etl import health_connect_etl

# Access TaskFlow functions directly
dag_instance = health_connect_etl()

def test_transform_glucose():
    """Test glucose transformation logic."""
    # Create test SQLite database
    import sqlite3
    import tempfile
    import os

    db_path = os.path.join(tempfile.mkdtemp(), 'test.db')
    conn = sqlite3.connect(db_path)
    conn.execute('''
        CREATE TABLE glucose_readings (
            timestamp TEXT,
            value REAL,
            unit TEXT,
            source_app TEXT
        )
    ''')
    conn.execute('''
        INSERT INTO glucose_readings VALUES
        ('2025-01-01T08:00:00', 120.5, 'mg/dL', 'Stelo')
    ''')
    conn.commit()
    conn.close()

    # Get the task function
    from dags.health_connect_etl import transform_glucose

    # Test
    result = transform_glucose.function(db_path)

    assert len(result) == 1
    assert result[0]['value_mg_dl'] == 120.5
    assert result[0]['source'] == 'Stelo'
```

## Mocking External Dependencies

```python
# tests/test_with_mocks.py
import pytest
from unittest.mock import patch, MagicMock

def test_pull_from_google_drive_success():
    """Test Google Drive download with mocked API."""
    from dags.health_connect_etl import pull_from_google_drive

    with patch('dags.health_connect_etl.build') as mock_build:
        mock_service = MagicMock()
        mock_build.return_value = mock_service

        mock_service.files().list().execute.return_value = {
            'files': [{'id': '123', 'name': 'health_connect_2025-01-01.zip'}]
        }

        result = pull_from_google_drive.function('2025-01-01')

        assert 'health_connect_2025-01-01.zip' in result

def test_pull_from_google_drive_no_file():
    """Test handling of missing file."""
    from dags.health_connect_etl import pull_from_google_drive

    with patch('dags.health_connect_etl.build') as mock_build:
        mock_service = MagicMock()
        mock_build.return_value = mock_service
        mock_service.files().list().execute.return_value = {'files': []}

        with pytest.raises(ValueError, match="No file found"):
            pull_from_google_drive.function('2025-01-01')
```

## Running Tests

```bash
# Run all DAG tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=dags --cov-report=html

# Run specific test file
pytest tests/test_health_connect_etl.py -v

# Run in Docker
docker compose exec airflow-scheduler pytest tests/ -v
```

## CI Integration

```yaml
# .github/workflows/test-dags.yml
name: Test DAGs

on:
  pull_request:
    paths:
      - 'dags/**'
      - 'tests/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install apache-airflow==2.8.1 pytest pytest-cov
          pip install -r requirements.txt

      - name: Run tests
        run: pytest tests/ -v --cov=dags
```
