USE DATABASE ECOMMERCE_RT;

-- Dynamic Tables for the Gold layer.
-- TARGET_LAG sets the max staleness -- Snowflake works out when to refresh.
-- DT_FRAUD_SIGNALS uses a CTE so fraud_score can reference the flag columns;
-- Snowflake doesn't allow alias references within the same SELECT list.

CREATE OR REPLACE DYNAMIC TABLE GOLD.DT_DAILY_REVENUE
  TARGET_LAG = '15 minutes'
  WAREHOUSE = WH_TRANSFORM_M
AS
SELECT
  TO_DATE(order_ts) AS order_date,
  shipping_country,
  COUNT(*) AS orders_count,
  COUNT(DISTINCT customer_id) AS customers_count,
  SUM(total_amount) AS revenue,
  AVG(total_amount) AS avg_order_value
FROM SILVER.ORDERS
WHERE status IN ('paid', 'shipped', 'completed')
GROUP BY 1, 2;

CREATE OR REPLACE DYNAMIC TABLE GOLD.DT_CUSTOMER_360
  TARGET_LAG = '30 minutes'
  WAREHOUSE = WH_TRANSFORM_M
AS
SELECT
  c.customer_id,
  c.email,
  c.full_name,
  c.country,
  c.customer_segment,
  COUNT(o.order_id) AS lifetime_orders,
  SUM(o.total_amount) AS lifetime_revenue,
  MAX(o.order_ts) AS last_order_ts,
  COUNT(e.event_id) AS total_clickstream_events,
  COUNT(DISTINCT e.session_id) AS total_sessions
FROM SILVER.CUSTOMERS_SCD2 c
LEFT JOIN SILVER.ORDERS o ON c.customer_id = o.customer_id
LEFT JOIN SILVER.CLICKSTREAM_EVENTS e ON c.customer_id = e.customer_id
WHERE c.is_current = TRUE
GROUP BY 1,2,3,4,5;

CREATE OR REPLACE DYNAMIC TABLE GOLD.DT_FRAUD_SIGNALS
  TARGET_LAG = '15 minutes'
  WAREHOUSE = WH_TRANSFORM_M
AS
WITH base AS (
  SELECT
    o.order_id,
    o.customer_id,
    o.order_ts,
    o.total_amount,
    o.payment_method,
    o.shipping_country,
    c.country AS customer_country,
    CASE WHEN o.total_amount > 1000 THEN 1 ELSE 0 END AS high_value_order_flag,
    CASE WHEN COUNT(*) OVER (PARTITION BY o.customer_id, DATE_TRUNC('hour', o.order_ts)) >= 5 THEN 1 ELSE 0 END AS velocity_flag,
    CASE WHEN c.country IS NOT NULL AND c.country <> o.shipping_country THEN 1 ELSE 0 END AS country_mismatch_flag
  FROM SILVER.ORDERS o
  LEFT JOIN SILVER.CUSTOMERS_SCD2 c
    ON o.customer_id = c.customer_id AND c.is_current = TRUE
)

SELECT
  *,
  high_value_order_flag + velocity_flag + country_mismatch_flag AS fraud_score
FROM base;
