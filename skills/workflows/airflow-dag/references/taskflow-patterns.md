# TaskFlow API Patterns

## Basic TaskFlow

```python
from airflow.decorators import dag, task
from datetime import datetime

@dag(
    schedule='@daily',
    start_date=datetime(2025, 1, 1),
    catchup=False
)
def my_dag():
    @task
    def extract() -> dict:
        return {'data': [1, 2, 3]}

    @task
    def transform(data: dict) -> list:
        return [x * 2 for x in data['data']]

    @task
    def load(data: list) -> None:
        print(f"Loaded {len(data)} records")

    # Chain tasks
    load(transform(extract()))

my_dag()
```

## Multiple Outputs

```python
@task(multiple_outputs=True)
def extract() -> dict:
    return {
        'users': [...],
        'orders': [...],
    }

@task
def process_users(users: list): ...

@task
def process_orders(orders: list): ...

# Use outputs
data = extract()
process_users(data['users'])
process_orders(data['orders'])
```

## Branching

```python
from airflow.decorators import task
from airflow.operators.python import BranchPythonOperator

@task.branch
def choose_path(data: dict) -> str:
    if data['count'] > 100:
        return 'high_volume_task'
    return 'low_volume_task'

@task
def high_volume_task(data): ...

@task
def low_volume_task(data): ...

# Usage
data = extract()
branch = choose_path(data)
high_volume_task(data)
low_volume_task(data)
```

## Dynamic Task Mapping

```python
@task
def get_partitions() -> list[str]:
    return ['2025-01-01', '2025-01-02', '2025-01-03']

@task
def process_partition(partition: str) -> dict:
    # Process single partition
    return {'partition': partition, 'count': 100}

@task
def aggregate(results: list[dict]) -> dict:
    total = sum(r['count'] for r in results)
    return {'total': total}

# Dynamic expansion
partitions = get_partitions()
results = process_partition.expand(partition=partitions)
aggregate(results)
```

## XCom with Large Data

<Bad>
@task
def extract() -> list:
    # Returns 1GB of data through XCom
    return massive_data
</Bad>

<Good>
@task
def extract() -> str:
    # Save to temp storage, return path
    path = '/tmp/data.parquet'
    df.to_parquet(path)
    return path

@task
def transform(data_path: str) -> str:
    df = pd.read_parquet(data_path)
    ...
</Good>

## Error Handling

```python
@task(retries=3, retry_delay=timedelta(minutes=5))
def flaky_api_call() -> dict:
    response = requests.get(API_URL)
    response.raise_for_status()
    return response.json()
```

## Task Groups

```python
from airflow.decorators import task_group

@task_group
def extract_transform():
    @task
    def extract(): ...

    @task
    def validate(data): ...

    @task
    def transform(data): ...

    data = extract()
    validated = validate(data)
    return transform(validated)

@dag(...)
def my_dag():
    et = extract_transform()
    load(et)
```

## Sensors with TaskFlow

```python
from airflow.sensors.filesystem import FileSensor
from airflow.decorators import dag, task

@dag(...)
def wait_and_process():
    wait_for_file = FileSensor(
        task_id='wait_for_file',
        filepath='/data/input.csv',
        poke_interval=60,
        timeout=3600
    )

    @task
    def process_file(file_path: str): ...

    wait_for_file >> process_file('/data/input.csv')
```

## Best Practices

1. **Type hints**: Always use type hints for clarity
2. **Docstrings**: Document task purpose, args, returns
3. **Small tasks**: Keep tasks focused and testable
4. **Idempotency**: Tasks should produce same result on re-run
5. **No side effects**: Don't modify external state unexpectedly
