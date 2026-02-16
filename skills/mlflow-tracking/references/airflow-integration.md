# MLflow in Airflow DAGs

## Environment Setup

Configure MLflow in your Airflow environment:

```yaml
# docker-compose.yml
x-airflow-common: &airflow-common
  environment:
    MLFLOW_TRACKING_URI: http://mlflow:5000
    MLFLOW_S3_ENDPOINT_URL: http://minio:9000
    AWS_ACCESS_KEY_ID: minioadmin
    AWS_SECRET_ACCESS_KEY: minioadmin
```

## Training DAG

```python
from airflow.decorators import dag, task
from datetime import datetime, timedelta

@dag(
    dag_id='ml_training_pipeline',
    schedule='@weekly',
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['ml', 'training']
)
def ml_training_pipeline():

    @task
    def prepare_data() -> str:
        """Prepare training data and return path."""
        import pandas as pd

        # Load and preprocess data
        df = pd.read_parquet('/data/glucose_readings.parquet')
        df_processed = preprocess(df)

        output_path = '/tmp/training_data.parquet'
        df_processed.to_parquet(output_path)
        return output_path

    @task
    def train_model(data_path: str) -> dict:
        """Train model and log to MLflow."""
        import mlflow
        import mlflow.pytorch
        import pandas as pd

        mlflow.set_tracking_uri('http://mlflow:5000')
        mlflow.set_experiment('glucose-anomaly-detection')

        df = pd.read_parquet(data_path)

        with mlflow.start_run() as run:
            # Log parameters
            params = {
                'model_type': 'lstm',
                'hidden_size': 128,
                'epochs': 100,
                'learning_rate': 0.001
            }
            mlflow.log_params(params)

            # Train
            model = train_lstm(df, **params)

            # Evaluate
            metrics = evaluate_model(model, df)
            mlflow.log_metrics(metrics)

            # Log model
            mlflow.pytorch.log_model(model, 'model')

            return {
                'run_id': run.info.run_id,
                'metrics': metrics
            }

    @task
    def evaluate_and_register(training_result: dict) -> dict:
        """Evaluate model and register if it beats production."""
        import mlflow
        from mlflow.tracking import MlflowClient

        client = MlflowClient()
        run_id = training_result['run_id']
        new_f1 = training_result['metrics']['f1']

        # Get current production model's F1
        try:
            prod_model = client.get_latest_versions(
                'glucose-anomaly-detector',
                stages=['Production']
            )[0]
            prod_run = client.get_run(prod_model.run_id)
            prod_f1 = prod_run.data.metrics.get('f1', 0)
        except:
            prod_f1 = 0

        # Register if better
        if new_f1 > prod_f1:
            model_uri = f'runs:/{run_id}/model'
            mv = mlflow.register_model(model_uri, 'glucose-anomaly-detector')

            client.transition_model_version_stage(
                name='glucose-anomaly-detector',
                version=mv.version,
                stage='Staging'
            )

            return {
                'registered': True,
                'version': mv.version,
                'improvement': new_f1 - prod_f1
            }

        return {'registered': False, 'reason': 'No improvement'}

    @task
    def notify_result(eval_result: dict):
        """Send notification about training result."""
        if eval_result.get('registered'):
            message = f"New model v{eval_result['version']} staged. " \
                      f"F1 improved by {eval_result['improvement']:.3f}"
        else:
            message = f"Training complete. {eval_result.get('reason', 'No update')}"

        # Send to Slack, email, etc.
        print(message)

    # DAG flow
    data_path = prepare_data()
    training_result = train_model(data_path)
    eval_result = evaluate_and_register(training_result)
    notify_result(eval_result)

ml_training_pipeline()
```

## Batch Inference DAG

```python
@dag(
    dag_id='ml_batch_inference',
    schedule='@daily',
    start_date=datetime(2025, 1, 1),
    catchup=True,
    tags=['ml', 'inference']
)
def ml_batch_inference():

    @task
    def load_production_model() -> str:
        """Load production model and return model URI."""
        import mlflow

        mlflow.set_tracking_uri('http://mlflow:5000')

        # This validates the model exists
        model = mlflow.pytorch.load_model(
            'models:/glucose-anomaly-detector/Production'
        )

        return 'models:/glucose-anomaly-detector/Production'

    @task
    def run_inference(model_uri: str, execution_date: str) -> str:
        """Run inference on daily data."""
        import mlflow.pytorch
        import pandas as pd

        model = mlflow.pytorch.load_model(model_uri)

        # Load data for date
        df = pd.read_parquet(f'/data/glucose/{execution_date}.parquet')

        # Run inference
        predictions = model.predict(df)

        # Save predictions
        output_path = f'/data/predictions/{execution_date}.parquet'
        predictions.to_parquet(output_path)

        return output_path

    @task
    def store_predictions(predictions_path: str) -> dict:
        """Store predictions in database."""
        import pandas as pd
        from sqlalchemy import create_engine

        df = pd.read_parquet(predictions_path)

        engine = create_engine('postgresql://...')
        df.to_sql('glucose_predictions', engine, if_exists='append')

        return {'records': len(df)}

    # DAG flow
    model_uri = load_production_model()
    predictions = run_inference(model_uri, '{{ ds }}')
    store_predictions(predictions)

ml_batch_inference()
```

## Model Promotion DAG

```python
@dag(
    dag_id='ml_model_promotion',
    schedule=None,  # Triggered manually or by webhook
    start_date=datetime(2025, 1, 1),
    tags=['ml', 'deployment']
)
def ml_model_promotion():

    @task
    def validate_staging_model() -> dict:
        """Run validation tests on staging model."""
        import mlflow
        from mlflow.tracking import MlflowClient

        client = MlflowClient()
        staging = client.get_latest_versions(
            'glucose-anomaly-detector',
            stages=['Staging']
        )[0]

        model = mlflow.pytorch.load_model(
            f'models:/glucose-anomaly-detector/{staging.version}'
        )

        # Run validation tests
        validation_results = run_validation_suite(model)

        return {
            'version': staging.version,
            'passed': validation_results['passed'],
            'details': validation_results
        }

    @task.branch
    def check_validation(validation: dict) -> str:
        if validation['passed']:
            return 'promote_to_production'
        return 'notify_failure'

    @task
    def promote_to_production(validation: dict):
        """Promote staging to production."""
        from mlflow.tracking import MlflowClient

        client = MlflowClient()
        client.transition_model_version_stage(
            name='glucose-anomaly-detector',
            version=validation['version'],
            stage='Production',
            archive_existing_versions=True
        )

    @task
    def notify_failure(validation: dict):
        """Notify about validation failure."""
        print(f"Validation failed: {validation['details']}")

    # DAG flow
    validation = validate_staging_model()
    check_validation(validation) >> [
        promote_to_production(validation),
        notify_failure(validation)
    ]

ml_model_promotion()
```
