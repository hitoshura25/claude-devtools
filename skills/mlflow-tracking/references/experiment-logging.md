# MLflow Experiment Logging

## Basic Tracking

```python
import mlflow

# Set experiment (creates if not exists)
mlflow.set_experiment("glucose-anomaly-detection")

# Start a run
with mlflow.start_run(run_name="baseline-lstm"):
    # Log parameters
    mlflow.log_params({
        "model_type": "lstm",
        "hidden_size": 128,
        "num_layers": 2,
        "learning_rate": 0.001,
        "batch_size": 32,
        "epochs": 100
    })

    # Training loop
    for epoch in range(100):
        train_loss = train_one_epoch()
        val_loss = validate()

        # Log metrics per step
        mlflow.log_metrics({
            "train_loss": train_loss,
            "val_loss": val_loss
        }, step=epoch)

    # Log final metrics
    mlflow.log_metrics({
        "final_train_loss": train_loss,
        "final_val_loss": val_loss,
        "precision": 0.92,
        "recall": 0.89,
        "f1": 0.90
    })

    # Log artifacts
    mlflow.log_artifact("config.yaml")
    mlflow.log_artifacts("plots/", artifact_path="figures")
```

## Autologging

MLflow can automatically log for supported frameworks:

```python
import mlflow

# PyTorch
mlflow.pytorch.autolog()

# Scikit-learn
mlflow.sklearn.autolog()

# XGBoost
mlflow.xgboost.autolog()

# TensorFlow/Keras
mlflow.tensorflow.autolog()

# Then just train normally
model.fit(X_train, y_train)
```

## Logging Models

### PyTorch

```python
import mlflow.pytorch

with mlflow.start_run():
    # Train model...

    # Log model
    mlflow.pytorch.log_model(
        model,
        "model",
        signature=mlflow.models.infer_signature(X_sample, y_sample),
        input_example=X_sample[:5]
    )
```

### Scikit-learn

```python
import mlflow.sklearn

with mlflow.start_run():
    model = RandomForestClassifier()
    model.fit(X_train, y_train)

    mlflow.sklearn.log_model(
        model,
        "model",
        signature=mlflow.models.infer_signature(X_train, model.predict(X_train))
    )
```

## Tags and Notes

```python
with mlflow.start_run():
    # Set tags for filtering
    mlflow.set_tags({
        "team": "ml-platform",
        "dataset_version": "v2.1",
        "experiment_type": "hyperparameter_tuning"
    })

    # Add description
    mlflow.set_tag("mlflow.note.content", """
    ## Experiment Notes
    - Testing LSTM vs Transformer for glucose prediction
    - Using 30-day lookback window
    - Dataset: Health Connect exports Jan-Jun 2025
    """)
```

## Nested Runs

```python
with mlflow.start_run(run_name="hyperparameter-search"):
    for lr in [0.001, 0.01, 0.1]:
        with mlflow.start_run(run_name=f"lr-{lr}", nested=True):
            mlflow.log_param("learning_rate", lr)
            # Train and log...
```

## Querying Runs

```python
from mlflow.tracking import MlflowClient

client = MlflowClient()

# Get experiment
experiment = client.get_experiment_by_name("glucose-anomaly-detection")

# Search runs
runs = client.search_runs(
    experiment_ids=[experiment.experiment_id],
    filter_string="metrics.f1 > 0.85 AND params.model_type = 'lstm'",
    order_by=["metrics.f1 DESC"],
    max_results=10
)

for run in runs:
    print(f"Run {run.info.run_id}: F1={run.data.metrics['f1']:.3f}")
```

## Best Practices

<Good>
# Log everything reproducibility needs
mlflow.log_params({
    "random_seed": 42,
    "data_split_ratio": 0.8,
    "preprocessing_version": "v2"
})
mlflow.log_artifact("requirements.txt")
</Good>

<Bad>
# Missing reproducibility info
mlflow.log_param("epochs", 100)
# What data? What preprocessing? What dependencies?
</Bad>
