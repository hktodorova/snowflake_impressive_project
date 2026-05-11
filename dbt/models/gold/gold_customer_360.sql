select
  c.customer_id,
  c.email,
  c.full_name,
  c.country,
  c.customer_segment,
  count(o.order_id) as lifetime_orders,
  sum(o.total_amount) as lifetime_revenue,
  max(o.order_ts) as last_order_ts,
  count(e.event_id) as clickstream_events,
  count(distinct e.session_id) as sessions,
  count_if(e.event_name = 'product_view') as product_views,
  count_if(e.event_name = 'add_to_cart') as add_to_cart_events
from {{ ref('silver_customers_current') }} c
left join {{ ref('silver_orders') }} o on c.customer_id = o.customer_id
left join {{ ref('silver_clickstream_events') }} e on c.customer_id = e.customer_id
group by 1,2,3,4,5
