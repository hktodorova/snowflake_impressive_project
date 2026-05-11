with base as (
  select
    o.order_id,
    o.customer_id,
    o.order_ts,
    o.total_amount,
    o.payment_method,
    o.shipping_country,
    c.country as customer_country,
    iff(o.total_amount > 1000, 1, 0) as high_value_order_flag,
    iff(count(*) over (partition by o.customer_id, date_trunc('hour', o.order_ts)) >= 5, 1, 0) as velocity_flag,
    iff(c.country is not null and c.country <> o.shipping_country, 1, 0) as country_mismatch_flag
  from {{ ref('silver_orders') }} o
  left join {{ ref('silver_customers_current') }} c on o.customer_id = c.customer_id
)

select
  *,
  high_value_order_flag + velocity_flag + country_mismatch_flag as fraud_score
from base
