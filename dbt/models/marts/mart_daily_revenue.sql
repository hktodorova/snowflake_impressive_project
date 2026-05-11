select
  to_date(order_ts) as order_date,
  shipping_country,
  count(*) as orders_count,
  count(distinct customer_id) as customers_count,
  sum(total_amount) as revenue,
  avg(total_amount) as avg_order_value
from {{ ref('silver_orders') }}
where status in ('paid', 'shipped', 'completed')
group by 1,2
