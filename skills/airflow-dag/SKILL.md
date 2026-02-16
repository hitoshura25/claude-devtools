---
name: airflow-dag
description: Use when creating data pipelines, ETL workflows, or scheduling batch jobs with Apache Airflow
---

# Airflow DAG Development

## Overview

Create production-ready Airflow DAGs using TaskFlow API.

**Announce at start:** "I'm using the airflow-dag skill to create the data pipeline."

**REQUIRED SUB-SKILL:** Use devtools:lint-python for code quality.

## When to Use

- ETL/ELT pipelines
- Scheduled data processing
- ML training orchestration

## TaskFlow Pattern

```python
@dag(schedule="@daily", catchup=True)
def my_pipeline():
    @task
    def extract(): ...

    @task
    def transform(data): ...

    @task
    def load(data): ...

    load(transform(extract()))
```

## Testing

```bash
pytest tests/test_dags.py -v
```

## References

- @references/taskflow-patterns.md - @task decorator patterns
- @references/docker-compose.md - Local Airflow setup
- @references/testing-dags.md - DagBag testing
- @references/health-connect-etl.md - Health data example

## Completion Criteria

- [ ] DAG loads without import errors
- [ ] All tasks have proper dependencies
- [ ] Idempotent operations (upsert logic)
- [ ] Unit tests pass
- [ ] Visible in Airflow UI
