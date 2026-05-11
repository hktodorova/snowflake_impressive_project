# Technical Design Notes

## What I was trying to solve

The scenario is a mid-size e-commerce company that has outgrown their nightly batch pipeline. Orders, clickstream events and customer CDC records all need to land fast enough to power same-day dashboards, near-real-time fraud detection and a customer 360 view that's actually fresh.

My goal was to design something that could realistically be run by a small data platform team — not a 30-person engineering org — so the operational overhead matters as much as the architecture.

## Core decisions and the reasoning behind them

### Keeping raw data as VARIANT

I store the full JSON payload in raw tables alongside ingestion metadata. It's a bit more storage but the replay value is worth it — when a source changes their schema (and they always do), you can re-parse from raw without going back to the source. I've seen teams lose weeks of data because they parsed on ingest and threw away the original. Not doing that here.

### Streams + Tasks vs. Airflow/Dagster

I used native Snowflake Streams and Tasks for the raw → silver pipeline rather than an external orchestrator. The main reason is simplicity — one less system to operate, and `SYSTEM$STREAM_HAS_DATA` means tasks only fire when there's actual work to do. The downside is that task dependency graphs are less ergonomic than DAGs in Airflow. For a team already invested in Airflow, I'd wire the merge logic as SQL operators instead and keep Tasks only for simple schedules.

### Dynamic Tables for Gold

Daily revenue and Customer 360 are Dynamic Tables with a 15–30 minute target lag. Snowflake handles the refresh scheduling and incremental computation — I don't need to write merge logic for these aggregations. The constraint is that Dynamic Tables don't support every SQL pattern (e.g. self-joins with non-deterministic functions), so I kept the fraud signal window function logic in a CTE to make the query plan predictable.

### dbt for Silver and below

Bronze is just views over raw — no transformation logic, just schema projection. Silver is where the actual work happens: deduplication, type casting, CDC merge via `row_number()`, and the SCD2 snapshot for customer history. I use dbt's `snapshot` feature for SCD2 rather than a custom merge stored proc because it gives me `dbt_valid_from/to` automatically and shows up in the lineage graph.

### RBAC design

Six roles, kept as flat as possible:

- `ROLE_DATA_PLATFORM_ADMIN` inherits from engineer and analytics
- `ROLE_BI_ANALYST` and `ROLE_DATA_SCIENTIST` inherit from analytics engineer
- `ROLE_EXTERNAL_PARTNER` is intentionally isolated — read-only on specific dynamic tables, behind the row access policy

The masking policy for email uses a regex that preserves the domain (`h***@gmail.com`) which is more useful for debugging than full redaction.

### Country-based row access via lookup table

The row access policy checks against `GOVERNANCE.ALLOWED_COUNTRIES` rather than a hardcoded list. This means adding a new country doesn't require a code change — you just insert a row. I've been burned by hardcoded lists in policies before; they tend to sit unreviewed for months.

### Feature table reproducibility

Both the dbt model and the Snowpark job accept an `as_of_timestamp` parameter. If you run feature generation with `2026-01-01` as the cutoff, you get exactly the same feature values you'd have seen on that date — useful for ML training data that needs to be reproducible. The `run_id` column lets you trace which batch of features was used for a given model version.

### Cost controls

Four warehouses sized for their workload. `WH_INGEST_XS` is tiny because Snowpipe and COPY don't need much. `WH_TRANSFORM_M` multi-clusters during heavy dbt runs. The resource monitor suspends the whole account at 100% of monthly budget — aggressive, but better than a surprise bill. Alerts fire at 80%.

## What I'd add in a real production deployment

- **Data contracts** at the source boundary — something like dbt-contracts or Soda checks that fail CI before a schema-breaking change lands in raw
- **Retry logic in Tasks** — currently if `TASK_MERGE_ORDERS` fails, it skips until the next schedule. A proper retry with exponential backoff would need a wrapper proc or external orchestration
- **Terraform for alerts and policies** — right now the Snowflake Alerts and row access policies are SQL-only. They should be in Terraform so a full redeploy doesn't lose them
- **Iceberg tables** for the raw layer if we need lakehouse interop with Spark or Trino consumers
- **Cortex** for enriching the customer 360 with sentiment from support tickets — low-hanging fruit given we already have Snowpark set up

## What I deliberately left out

Full CI against a live Snowflake account. The CI pipeline runs SQL lint, Python checks and `dbt parse` offline, and `terraform validate` without a backend. A connected CI environment would add `dbt run --target ci` against a dedicated schema and run `dbt test` after. I skipped this because it requires secrets management that doesn't belong in a public portfolio repo.
