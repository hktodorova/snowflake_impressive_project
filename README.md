# Real-Time E-Commerce Data Platform on Snowflake

**Hristina Todorova** · [hktodorova@gmail.com](mailto:hktodorova@gmail.com)

---

This is my personal portfolio project — a full data platform built on Snowflake for an e-commerce use case. I built it to show how I'd approach a production setup end-to-end, not just the transformation layer.

The stack covers ingestion (batch + streaming), a Bronze/Silver/Gold medallion model, dbt for transformations, Snowpark for ML features, governance with proper RBAC and masking, observability with alerts, and IaC with Terraform. It's opinionated where it should be and I've tried to document the reasoning behind key decisions in `docs/technical_design.md`.

## What's in here

```text
sql/          → setup, ingestion, transformations, governance, observability (run in order)
dbt/          → Bronze views, Silver incremental models, Gold tables, feature engineering
snowpark/     → Snowpark Python jobs for feature computation
terraform/    → infrastructure as code (warehouses, roles, schemas)
kafka/        → Snowpipe Streaming example for CDC and clickstream
docs/         → architecture diagram + design decisions
scripts/      → local data generator so you can run this without a live source
tests/        → smoke test that checks the repo structure is intact
```

## Running it locally

```bash
python -m venv .venv
.venv\Scripts\activate          # on Windows
pip install -r requirements.txt
python scripts/generate_sample_data.py
python snowpark/data_quality_local_demo.py
python tests/smoke_test_project.py
```

## Running on Snowflake

Execute the SQL files in this order:

```text
sql/00_setup/01_roles_warehouses_databases.sql
sql/00_setup/02_file_formats_stages.sql
sql/01_ingestion/01_raw_tables.sql
sql/01_ingestion/02_copy_and_snowpipe.sql
sql/02_transformations/01_streams_tasks.sql
sql/02_transformations/02_dynamic_tables.sql
sql/03_governance/01_security_governance.sql
sql/04_observability/01_monitoring_views.sql
```

Then dbt:

```bash
cd dbt
dbt deps
dbt seed
dbt snapshot   # SCD2 customer history
dbt run
dbt test
dbt docs generate
```

## A few things worth noting

- Raw tables keep the full VARIANT payload — makes it easy to replay after a schema change without losing data
- Warehouses are split by workload (ingest / transform / analytics / ML) so a heavy dbt run doesn't kill BI query performance
- The row access policy for countries pulls from a lookup table rather than hardcoding — easier to change without redeploying
- Feature tables store a `run_id` and `as_of_timestamp` so you can trace exactly which features went into a given model training run

## Credentials

No credentials, secrets or environment-specific config is committed here. Use environment variables or a secret manager of your choice for the Snowflake connection.
