# Health Connect ETL DAG

Example DAG for pulling Health Connect exports from Google Drive.

```python
from airflow.decorators import dag, task
from datetime import datetime

@dag(
    dag_id='health_connect_etl',
    schedule='@daily',
    start_date=datetime(2025, 9, 1),
    catchup=True,
    tags=['health-connect', 'etl']
)
def health_connect_etl():

    @task
    def pull_from_google_drive(execution_date: str) -> str:
        """Download Health Connect zip for date."""
        # Google Drive API integration
        ...

    @task
    def extract_sqlite(zip_path: str) -> str:
        """Extract SQLite from zip."""
        ...

    @task
    def transform_glucose(sqlite_path: str) -> list[dict]:
        """Transform Stelo glucose readings."""
        ...

    @task
    def load_to_postgres(data: list[dict]) -> dict:
        """Upsert to PostgreSQL."""
        ...

    # Flow
    zip_path = pull_from_google_drive("{{ ds }}")
    sqlite_path = extract_sqlite(zip_path)
    glucose = transform_glucose(sqlite_path)
    load_to_postgres(glucose)

health_connect_etl()
```

## Full Implementation

```python
from airflow.decorators import dag, task
from airflow.providers.postgres.hooks.postgres import PostgresHook
from datetime import datetime
import zipfile
import sqlite3
import tempfile
import os

@dag(
    dag_id='health_connect_etl',
    schedule='@daily',
    start_date=datetime(2025, 9, 1),
    catchup=True,
    tags=['health-connect', 'etl'],
    default_args={
        'retries': 2,
        'retry_delay': timedelta(minutes=5),
    }
)
def health_connect_etl():

    @task
    def pull_from_google_drive(execution_date: str) -> str:
        """Download Health Connect zip for date.

        Args:
            execution_date: Airflow execution date (YYYY-MM-DD)

        Returns:
            Path to downloaded zip file
        """
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaIoBaseDownload
        import io

        # Service account credentials from Airflow connection
        creds = service_account.Credentials.from_service_account_file(
            '/opt/airflow/secrets/google-sa.json',
            scopes=['https://www.googleapis.com/auth/drive.readonly']
        )

        service = build('drive', 'v3', credentials=creds)

        # Find file by date pattern
        query = f"name contains 'health_connect_{execution_date}'"
        results = service.files().list(q=query, fields='files(id, name)').execute()

        if not results.get('files'):
            raise ValueError(f"No file found for {execution_date}")

        file_id = results['files'][0]['id']
        file_name = results['files'][0]['name']

        # Download
        request = service.files().get_media(fileId=file_id)
        output_path = f"/tmp/{file_name}"

        with open(output_path, 'wb') as f:
            downloader = MediaIoBaseDownload(f, request)
            done = False
            while not done:
                status, done = downloader.next_chunk()

        return output_path

    @task
    def extract_sqlite(zip_path: str) -> str:
        """Extract SQLite database from Health Connect zip.

        Args:
            zip_path: Path to the zip file

        Returns:
            Path to extracted SQLite database
        """
        extract_dir = tempfile.mkdtemp()

        with zipfile.ZipFile(zip_path, 'r') as z:
            z.extractall(extract_dir)

        # Find .db file
        for root, dirs, files in os.walk(extract_dir):
            for f in files:
                if f.endswith('.db'):
                    return os.path.join(root, f)

        raise ValueError("No SQLite database found in zip")

    @task
    def transform_glucose(sqlite_path: str) -> list[dict]:
        """Extract and transform glucose readings from SQLite.

        Args:
            sqlite_path: Path to SQLite database

        Returns:
            List of glucose reading dictionaries
        """
        conn = sqlite3.connect(sqlite_path)
        conn.row_factory = sqlite3.Row

        cursor = conn.execute("""
            SELECT
                timestamp,
                value,
                unit,
                source_app
            FROM glucose_readings
            ORDER BY timestamp
        """)

        readings = []
        for row in cursor:
            readings.append({
                'timestamp': row['timestamp'],
                'value_mg_dl': row['value'],
                'unit': row['unit'],
                'source': row['source_app'],
                'processed_at': datetime.utcnow().isoformat()
            })

        conn.close()
        return readings

    @task
    def load_to_postgres(data: list[dict]) -> dict:
        """Upsert glucose readings to PostgreSQL.

        Args:
            data: List of glucose reading dictionaries

        Returns:
            Summary of inserted/updated records
        """
        hook = PostgresHook(postgres_conn_id='health_postgres')
        conn = hook.get_conn()
        cursor = conn.cursor()

        inserted = 0
        updated = 0

        for record in data:
            cursor.execute("""
                INSERT INTO glucose_readings (timestamp, value_mg_dl, unit, source, processed_at)
                VALUES (%(timestamp)s, %(value_mg_dl)s, %(unit)s, %(source)s, %(processed_at)s)
                ON CONFLICT (timestamp, source)
                DO UPDATE SET
                    value_mg_dl = EXCLUDED.value_mg_dl,
                    processed_at = EXCLUDED.processed_at
                RETURNING (xmax = 0) as inserted
            """, record)

            result = cursor.fetchone()
            if result[0]:
                inserted += 1
            else:
                updated += 1

        conn.commit()
        cursor.close()

        return {'inserted': inserted, 'updated': updated, 'total': len(data)}

    # DAG flow
    zip_path = pull_from_google_drive("{{ ds }}")
    sqlite_path = extract_sqlite(zip_path)
    glucose = transform_glucose(sqlite_path)
    load_to_postgres(glucose)

health_connect_etl()
```
