USE DATABASE ECOMMERCE_RT;
USE SCHEMA OBSERVABILITY;

CREATE OR REPLACE VIEW V_TASK_FAILURES AS
SELECT
  name AS task_name,
  state,
  completed_time,
  error_code,
  error_message,
  query_id
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE state = 'FAILED';

CREATE OR REPLACE VIEW V_WAREHOUSE_COST_ATTRIBUTION AS
SELECT
  DATE_TRUNC('day', start_time) AS usage_day,
  warehouse_name,
  SUM(credits_used) AS credits_used
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
GROUP BY 1, 2;

CREATE OR REPLACE VIEW V_QUERY_LATENCY AS
SELECT
  DATE_TRUNC('hour', start_time) AS query_hour,
  warehouse_name,
  role_name,
  COUNT(*) AS query_count,
  AVG(total_elapsed_time) / 1000 AS avg_elapsed_seconds,
  APPROX_PERCENTILE(total_elapsed_time / 1000, 0.95) AS p95_elapsed_seconds,
  SUM(bytes_scanned) / POWER(1024, 3) AS gb_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY 1,2,3;

CREATE OR REPLACE VIEW V_DATA_FRESHNESS AS
SELECT 'RAW_ORDERS' AS table_name, MAX(ingested_at) AS last_ingested_at, DATEDIFF('minute', MAX(ingested_at), CURRENT_TIMESTAMP()) AS freshness_lag_minutes FROM RAW.RAW_ORDERS
UNION ALL
SELECT 'RAW_CLICKSTREAM', MAX(ingested_at), DATEDIFF('minute', MAX(ingested_at), CURRENT_TIMESTAMP()) FROM RAW.RAW_CLICKSTREAM
UNION ALL
SELECT 'SILVER_ORDERS', MAX(updated_at), DATEDIFF('minute', MAX(updated_at), CURRENT_TIMESTAMP()) FROM SILVER.ORDERS;

-- ---------------------------------------------------------------------------
-- Alerts: автоматично известяване при task failures и freshness нарушения.
-- Изисква EXECUTE ALERT привилегия за роля DATA_PLATFORM_ADMIN.
-- ---------------------------------------------------------------------------

USE ROLE SYSADMIN;

-- Alert: Task failure в последния час
CREATE OR REPLACE ALERT ALERT_TASK_FAILURE
  WAREHOUSE = WH_INGEST_XS
  SCHEDULE = '10 MINUTES'
  IF (
    EXISTS (
      SELECT 1
      FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD('minute', -10, CURRENT_TIMESTAMP()),
        RESULT_LIMIT => 10
      ))
      WHERE state = 'FAILED'
    )
  )
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'EMAIL_INT_ALERTS',
      'hktodorova@gmail.com',
      'ALERT: Snowflake Task Failure Detected',
      'One or more Snowflake Tasks have failed in the last 10 minutes. Check ECOMMERCE_RT.OBSERVABILITY.V_TASK_FAILURES for details.'
    );

-- Alert: RAW_ORDERS freshness lag > 60 минути
CREATE OR REPLACE ALERT ALERT_ORDERS_FRESHNESS
  WAREHOUSE = WH_INGEST_XS
  SCHEDULE = '15 MINUTES'
  IF (
    EXISTS (
      SELECT 1
      FROM OBSERVABILITY.V_DATA_FRESHNESS
      WHERE table_name = 'RAW_ORDERS'
        AND freshness_lag_minutes > 60
    )
  )
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'EMAIL_INT_ALERTS',
      'hktodorova@gmail.com',
      'ALERT: RAW_ORDERS Freshness SLA Breach',
      'RAW_ORDERS has not received new data for over 60 minutes. Investigate Snowpipe or upstream ingestion.'
    );

-- Alert: Daily credit usage > 80% от resource monitor прага (500 * 0.8 = 400)
CREATE OR REPLACE ALERT ALERT_HIGH_CREDIT_USAGE
  WAREHOUSE = WH_INGEST_XS
  SCHEDULE = '60 MINUTES'
  IF (
    EXISTS (
      SELECT 1
      FROM OBSERVABILITY.V_WAREHOUSE_COST_ATTRIBUTION
      WHERE usage_day = CURRENT_DATE()
        AND credits_used > 400
      HAVING SUM(credits_used) > 400
    )
  )
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'EMAIL_INT_ALERTS',
      'hktodorova@gmail.com',
      'ALERT: High Snowflake Credit Usage Today',
      'Daily Snowflake credit consumption has exceeded 400 credits (80% of monthly budget). Review OBSERVABILITY.V_WAREHOUSE_COST_ATTRIBUTION.'
    );

-- Активиране на alerts (по подразбиране са suspended след CREATE)
ALTER ALERT ALERT_TASK_FAILURE RESUME;
ALTER ALERT ALERT_ORDERS_FRESHNESS RESUME;
ALTER ALERT ALERT_HIGH_CREDIT_USAGE RESUME;
