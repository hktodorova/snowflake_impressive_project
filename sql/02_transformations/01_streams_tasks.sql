USE DATABASE ECOMMERCE_RT;

-- Silver table DDL. Constraints are NOT ENFORCED -- Snowflake doesn't enforce PKs,
-- but declaring them documents intent and can help some query planners.
-- Clustered on (date, customer_id) because most filters start with a date range.

CREATE TABLE IF NOT EXISTS SILVER.ORDERS (
  order_id STRING NOT NULL,
  customer_id STRING NOT NULL,
  order_ts TIMESTAMP_NTZ NOT NULL,
  status STRING,
  currency STRING,
  total_amount NUMBER(12,2),
  payment_method STRING,
  shipping_country STRING,
  source_system STRING,
  ingested_at TIMESTAMP_NTZ,
  updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  CONSTRAINT PK_ORDERS PRIMARY KEY (order_id) NOT ENFORCED
)
CLUSTER BY (TO_DATE(order_ts), customer_id);

CREATE TABLE IF NOT EXISTS SILVER.CLICKSTREAM_EVENTS (
  event_id STRING NOT NULL,
  session_id STRING,
  customer_id STRING,
  anonymous_id STRING,
  event_name STRING,
  event_ts TIMESTAMP_NTZ,
  page_url STRING,
  product_sku STRING,
  device_type STRING,
  geo_country STRING,
  ingested_at TIMESTAMP_NTZ,
  CONSTRAINT PK_CLICKSTREAM PRIMARY KEY (event_id) NOT ENFORCED
)
CLUSTER BY (TO_DATE(event_ts), customer_id);

CREATE TABLE IF NOT EXISTS SILVER.CUSTOMERS_SCD2 (
  customer_sk STRING,
  customer_id STRING,
  email STRING,
  full_name STRING,
  country STRING,
  customer_segment STRING,
  valid_from TIMESTAMP_NTZ,
  valid_to TIMESTAMP_NTZ,
  is_current BOOLEAN,
  record_hash STRING,
  updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY (customer_id, is_current);

CREATE STREAM IF NOT EXISTS RAW.STREAM_RAW_ORDERS ON TABLE RAW.RAW_ORDERS APPEND_ONLY = TRUE;
CREATE STREAM IF NOT EXISTS RAW.STREAM_RAW_CLICKSTREAM ON TABLE RAW.RAW_CLICKSTREAM APPEND_ONLY = TRUE;
CREATE STREAM IF NOT EXISTS RAW.STREAM_RAW_CUSTOMERS_CDC ON TABLE RAW.RAW_CUSTOMERS_CDC APPEND_ONLY = TRUE;

CREATE OR REPLACE TASK UTIL.TASK_MERGE_ORDERS
  WAREHOUSE = WH_TRANSFORM_M
  SCHEDULE = '5 MINUTES'
  WHEN SYSTEM$STREAM_HAS_DATA('RAW.STREAM_RAW_ORDERS')
AS
MERGE INTO SILVER.ORDERS t
USING (
  SELECT * FROM (
    SELECT
      raw_payload:order_id::STRING AS order_id,
      raw_payload:customer_id::STRING AS customer_id,
      TRY_TO_TIMESTAMP_NTZ(raw_payload:order_ts::STRING) AS order_ts,
      raw_payload:status::STRING AS status,
      COALESCE(raw_payload:currency::STRING, 'USD') AS currency,
      raw_payload:total_amount::NUMBER(12,2) AS total_amount,
      raw_payload:payment_method::STRING AS payment_method,
      raw_payload:shipping_country::STRING AS shipping_country,
      source_system,
      ingested_at,
      ROW_NUMBER() OVER (PARTITION BY raw_payload:order_id::STRING ORDER BY ingested_at DESC) AS rn
    FROM RAW.STREAM_RAW_ORDERS
    WHERE raw_payload:order_id IS NOT NULL
  ) WHERE rn = 1
) s
ON t.order_id = s.order_id
WHEN MATCHED THEN UPDATE SET
  customer_id = s.customer_id,
  order_ts = s.order_ts,
  status = s.status,
  currency = s.currency,
  total_amount = s.total_amount,
  payment_method = s.payment_method,
  shipping_country = s.shipping_country,
  source_system = s.source_system,
  ingested_at = s.ingested_at,
  updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
  order_id, customer_id, order_ts, status, currency, total_amount, payment_method, shipping_country, source_system, ingested_at
) VALUES (
  s.order_id, s.customer_id, s.order_ts, s.status, s.currency, s.total_amount, s.payment_method, s.shipping_country, s.source_system, s.ingested_at
);

CREATE OR REPLACE TASK UTIL.TASK_MERGE_CLICKSTREAM
  WAREHOUSE = WH_TRANSFORM_M
  SCHEDULE = '5 MINUTES'
  WHEN SYSTEM$STREAM_HAS_DATA('RAW.STREAM_RAW_CLICKSTREAM')
AS
MERGE INTO SILVER.CLICKSTREAM_EVENTS t
USING (
  SELECT * FROM (
    SELECT
      raw_payload:event_id::STRING AS event_id,
      raw_payload:session_id::STRING AS session_id,
      raw_payload:customer_id::STRING AS customer_id,
      raw_payload:anonymous_id::STRING AS anonymous_id,
      raw_payload:event_name::STRING AS event_name,
      TRY_TO_TIMESTAMP_NTZ(raw_payload:event_ts::STRING) AS event_ts,
      raw_payload:page_url::STRING AS page_url,
      raw_payload:product_sku::STRING AS product_sku,
      raw_payload:device_type::STRING AS device_type,
      raw_payload:geo_country::STRING AS geo_country,
      ingested_at,
      ROW_NUMBER() OVER (PARTITION BY raw_payload:event_id::STRING ORDER BY ingested_at DESC) AS rn
    FROM RAW.STREAM_RAW_CLICKSTREAM
    WHERE raw_payload:event_id IS NOT NULL
  ) WHERE rn = 1
) s
ON t.event_id = s.event_id
WHEN NOT MATCHED THEN INSERT (
  event_id, session_id, customer_id, anonymous_id, event_name, event_ts, page_url, product_sku, device_type, geo_country, ingested_at
) VALUES (
  s.event_id, s.session_id, s.customer_id, s.anonymous_id, s.event_name, s.event_ts, s.page_url, s.product_sku, s.device_type, s.geo_country, s.ingested_at
);

-- SCD2 task: closes changed current records and inserts new versions.
CREATE OR REPLACE TASK UTIL.TASK_CUSTOMERS_SCD2
  WAREHOUSE = WH_TRANSFORM_M
  SCHEDULE = '10 MINUTES'
  WHEN SYSTEM$STREAM_HAS_DATA('RAW.STREAM_RAW_CUSTOMERS_CDC')
AS
BEGIN
  CREATE OR REPLACE TEMP TABLE UTIL.TMP_CUSTOMER_CDC AS
  SELECT * FROM (
    SELECT
      raw_payload:customer_id::STRING AS customer_id,
      raw_payload:email::STRING AS email,
      raw_payload:full_name::STRING AS full_name,
      raw_payload:country::STRING AS country,
      raw_payload:customer_segment::STRING AS customer_segment,
      COALESCE(event_ts, ingested_at) AS valid_from,
      SHA2(CONCAT_WS('|', raw_payload:email::STRING, raw_payload:full_name::STRING, raw_payload:country::STRING, raw_payload:customer_segment::STRING), 256) AS record_hash,
      ROW_NUMBER() OVER (PARTITION BY raw_payload:customer_id::STRING ORDER BY COALESCE(event_ts, ingested_at) DESC) AS rn
    FROM RAW.STREAM_RAW_CUSTOMERS_CDC
    WHERE op IN ('c','u','r')
  ) WHERE rn = 1;

  UPDATE SILVER.CUSTOMERS_SCD2 t
  SET valid_to = s.valid_from, is_current = FALSE, updated_at = CURRENT_TIMESTAMP()
  FROM UTIL.TMP_CUSTOMER_CDC s
  WHERE t.customer_id = s.customer_id
    AND t.is_current = TRUE
    AND t.record_hash <> s.record_hash;

  INSERT INTO SILVER.CUSTOMERS_SCD2 (
    customer_sk, customer_id, email, full_name, country, customer_segment, valid_from, valid_to, is_current, record_hash
  )
  SELECT
    SHA2(CONCAT(customer_id, '|', valid_from::STRING), 256), customer_id, email, full_name, country, customer_segment,
    valid_from, NULL, TRUE, record_hash
  FROM UTIL.TMP_CUSTOMER_CDC s
  WHERE NOT EXISTS (
    SELECT 1 FROM SILVER.CUSTOMERS_SCD2 t
    WHERE t.customer_id = s.customer_id AND t.is_current = TRUE AND t.record_hash = s.record_hash
  );
END;

ALTER TASK UTIL.TASK_MERGE_ORDERS RESUME;
ALTER TASK UTIL.TASK_MERGE_CLICKSTREAM RESUME;
ALTER TASK UTIL.TASK_CUSTOMERS_SCD2 RESUME;
