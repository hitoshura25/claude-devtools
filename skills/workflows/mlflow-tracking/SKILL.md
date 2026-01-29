---
name: mlflow-tracking
description: Use when tracking ML experiments, versioning models, or comparing training runs
---

# MLflow Tracking

## Overview

Track ML experiments, version models, compare runs with MLflow.

**Announce at start:** "I'm using the mlflow-tracking skill to set up experiment tracking."

## When to Use

- Training ML models
- Comparing hyperparameters
- Model versioning/deployment

## Basic Usage

```python
import mlflow

mlflow.set_experiment("glucose-anomaly")

with mlflow.start_run():
    mlflow.log_params({"lr": 0.001})
    mlflow.log_metrics({"loss": 0.05})
    mlflow.pytorch.log_model(model, "model")
```

## Model Registry

```python
mlflow.register_model(f"runs:/{run_id}/model", "my-model")
client.transition_model_version_stage("my-model", 1, "Production")
```

## References

- @references/docker-compose.md - Local MLflow server
- @references/experiment-logging.md - Tracking patterns
- @references/model-registry.md - Staging/Production
- @references/airflow-integration.md - MLflow in DAGs

## Completion Criteria

- [ ] MLflow server running (localhost:5000)
- [ ] Experiments created
- [ ] Runs logged with params/metrics
- [ ] Models registered
- [ ] Can load by stage
