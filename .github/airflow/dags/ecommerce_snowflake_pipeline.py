import logging
from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

log = logging.getLogger(__name__)


def validate_pipeline():
    import subprocess
    result = subprocess.run(
        ["python", "snowpark/data_quality_local_demo.py"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        log.error(result.stderr)
        raise RuntimeError("Data quality validation failed")
    log.info(result.stdout)


default_args = {
    "owner": "hristina-todorova",
    "depends_on_past": False,
    "retries": 1,
}

with DAG(
    dag_id="ecommerce_snowflake_data_platform",
    default_args=default_args,
    start_date=datetime(2025, 1, 1),
    schedule="@daily",
    catchup=False,
    tags=["snowflake", "dbt", "ecommerce"],
) as dag:

    generate_sample_data = BashOperator(
        task_id="generate_sample_data",
        bash_command="python scripts/generate_sample_data.py",
    )

    load_raw_data = BashOperator(
        task_id="load_raw_data",
        bash_command="cd dbt && dbt seed --select country_regions",
    )

    run_dbt_models = BashOperator(
        task_id="run_dbt_models",
        bash_command="cd dbt && dbt run",
    )

    run_dbt_tests = BashOperator(
        task_id="run_dbt_tests",
        bash_command="cd dbt && dbt test",
    )

    validate_data_quality = PythonOperator(
        task_id="validate_data_quality",
        python_callable=validate_pipeline,
    )

    publish_gold_marts = BashOperator(
        task_id="publish_gold_marts",
        bash_command="cd dbt && dbt run --select gold.*",
    )

    (
        generate_sample_data
        >> load_raw_data
        >> run_dbt_models
        >> run_dbt_tests
        >> validate_data_quality
        >> publish_gold_marts
    )