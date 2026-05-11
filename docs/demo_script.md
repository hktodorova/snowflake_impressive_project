# Demo walkthrough

This is my rough order when presenting the project. Not a script to read from — just a reminder of what to show and what's worth explaining.

**1. Start with the problem**
The company has nightly batch pipelines that can't support same-day dashboards or real-time fraud detection. Orders, CDC and clickstream all need to land and be queryable within minutes, not hours.

**2. Architecture overview**
Open `docs/architecture.md`. Walk through the two ingestion paths (batch via stage, streaming via Kafka). Explain why raw bronze keeps the full VARIANT — replay capability after schema changes.

**3. Show local data generation**

```bash
python scripts/generate_sample_data.py
```

Quick way to see what the source payloads look like without needing a live system.

**4. Snowflake setup SQL**
Walk through `sql/00_setup/` — four warehouses sized by workload, six roles with inheritance, one resource monitor shared across all warehouses.

**5. Ingestion**
`sql/01_ingestion/` — show the raw table DDL with VARIANT column, then COPY and Snowpipe setup. Mention that Snowpipe Streaming (for CDC/clickstream) lands data in seconds rather than the minute-plus latency of file-based Snowpipe.

**6. Streams and Tasks**
`sql/02_transformations/01_streams_tasks.sql` — the MERGE task only fires when `SYSTEM$STREAM_HAS_DATA` is true, so it doesn't waste credits on empty runs. Show the dedup logic inside the USING clause.

**7. Dynamic Tables**
`sql/02_transformations/02_dynamic_tables.sql` — Customer 360 and daily revenue. TARGET_LAG tells Snowflake how stale the data is allowed to be; it figures out the refresh schedule. No cron, no orchestrator needed for these.

**8. dbt models**
Open the dbt lineage graph (`dbt docs serve`). Show Bronze → Silver → Gold → Marts flow. Point out the snapshot for SCD2, the fraud signal CTE pattern, and the feature model's `as_of_timestamp` variable.

**9. Governance**
`sql/03_governance/` — masking policy on email (regex, not full redaction), row access policy pointing at a lookup table, tags for classification and ownership. Show that `ROLE_EXTERNAL_PARTNER` has minimal access by design.

**10. Observability**
`sql/04_observability/` — four views covering task failures, warehouse cost by day, query latency with p95, and data freshness lag in minutes. Plus three Alerts that fire on task failure, freshness SLA breach and high credit burn.

**Worth discussing in more detail if asked:**

- Why Streams + Tasks instead of Airflow (operational simplicity, fewer moving parts)
- The trade-off on Dynamic Tables vs. dbt incremental for Gold layer
- How `run_id` + `as_of_timestamp` in the feature table enables ML reproducibility
- What's missing: data contracts, Task retry logic, Terraform coverage for Alerts
