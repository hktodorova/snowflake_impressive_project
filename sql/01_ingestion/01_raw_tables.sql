USE DATABASE ECOMMERCE_RT;
USE SCHEMA RAW;

CREATE TABLE IF NOT EXISTS RAW_ORDERS (
  raw_payload VARIANT,
  source_system STRING,
  source_file STRING,
  source_row_number NUMBER,
  load_id STRING,
  ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  record_hash STRING
);

CREATE TABLE IF NOT EXISTS RAW_CUSTOMERS_CDC (
  raw_payload VARIANT,
  op STRING,
  source_lsn STRING,
  event_ts TIMESTAMP_NTZ,
  ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  record_hash STRING
);

CREATE TABLE IF NOT EXISTS RAW_CLICKSTREAM (
  raw_payload VARIANT,
  event_id STRING,
  session_id STRING,
  event_ts TIMESTAMP_NTZ,
  ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  record_hash STRING
);

CREATE TABLE IF NOT EXISTS RAW_PAYMENTS (
  raw_payload VARIANT,
  payment_id STRING,
  event_ts TIMESTAMP_NTZ,
  ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  record_hash STRING
);

CREATE TABLE IF NOT EXISTS RAW_PARTNER_PRODUCTS (
  partner_id STRING,
  product_sku STRING,
  category STRING,
  brand STRING,
  list_price NUMBER(12,2),
  source_file STRING,
  ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS LOAD_ERRORS (
  source_name STRING,
  source_file STRING,
  error_reason STRING,
  raw_payload VARIANT,
  created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
