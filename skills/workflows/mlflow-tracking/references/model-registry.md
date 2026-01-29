# MLflow Model Registry

## Registering Models

### From a Run

```python
import mlflow

# During training
with mlflow.start_run() as run:
    mlflow.pytorch.log_model(model, "model")
    run_id = run.info.run_id

# Register after training
model_uri = f"runs:/{run_id}/model"
mlflow.register_model(model_uri, "glucose-anomaly-detector")
```

### Direct Registration

```python
with mlflow.start_run():
    mlflow.pytorch.log_model(
        model,
        "model",
        registered_model_name="glucose-anomaly-detector"
    )
```

## Model Stages

Models progress through stages:
- **None** → Initial state
- **Staging** → Testing/validation
- **Production** → Live serving
- **Archived** → Deprecated

### Transitioning Stages

```python
from mlflow.tracking import MlflowClient

client = MlflowClient()

# Promote to staging
client.transition_model_version_stage(
    name="glucose-anomaly-detector",
    version=1,
    stage="Staging"
)

# Promote to production
client.transition_model_version_stage(
    name="glucose-anomaly-detector",
    version=1,
    stage="Production",
    archive_existing_versions=True  # Archive current production
)
```

## Loading Models by Stage

```python
import mlflow

# Load production model
model = mlflow.pytorch.load_model(
    "models:/glucose-anomaly-detector/Production"
)

# Load specific version
model = mlflow.pytorch.load_model(
    "models:/glucose-anomaly-detector/1"
)

# Load staging for testing
staging_model = mlflow.pytorch.load_model(
    "models:/glucose-anomaly-detector/Staging"
)
```

## Model Metadata

### Adding Descriptions

```python
client = MlflowClient()

# Model description
client.update_registered_model(
    name="glucose-anomaly-detector",
    description="LSTM-based anomaly detection for glucose readings"
)

# Version description
client.update_model_version(
    name="glucose-anomaly-detector",
    version=1,
    description="Baseline model, trained on Jan-Jun 2025 data"
)
```

### Tags

```python
# Model-level tags
client.set_registered_model_tag(
    name="glucose-anomaly-detector",
    key="team",
    value="ml-platform"
)

# Version-level tags
client.set_model_version_tag(
    name="glucose-anomaly-detector",
    version=1,
    key="validation_status",
    value="approved"
)
```

## Listing and Searching

```python
from mlflow.tracking import MlflowClient

client = MlflowClient()

# List all registered models
for model in client.search_registered_models():
    print(f"Model: {model.name}")

# Get specific model
model = client.get_registered_model("glucose-anomaly-detector")
print(f"Latest versions: {model.latest_versions}")

# Get production version
for version in model.latest_versions:
    if version.current_stage == "Production":
        print(f"Production: v{version.version}")

# Search model versions
versions = client.search_model_versions("name='glucose-anomaly-detector'")
for v in versions:
    print(f"v{v.version}: {v.current_stage}")
```

## Deployment Pattern

```python
def get_production_model(model_name: str):
    """Load the current production model."""
    try:
        model = mlflow.pytorch.load_model(
            f"models:/{model_name}/Production"
        )
        return model
    except Exception as e:
        # Fallback to staging if production unavailable
        return mlflow.pytorch.load_model(
            f"models:/{model_name}/Staging"
        )

# In serving code
model = get_production_model("glucose-anomaly-detector")
predictions = model.predict(input_data)
```

## Webhook Notifications

MLflow supports webhooks for model registry events:

```python
from mlflow.tracking import MlflowClient

client = MlflowClient()

# Create webhook for model transitions
client.create_registry_webhook(
    events=["MODEL_VERSION_TRANSITIONED_STAGE"],
    description="Notify on production deployment",
    http_url_spec={
        "url": "https://api.example.com/mlflow-webhook",
        "secret": "webhook-secret"
    }
)
```
