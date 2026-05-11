{{ config(unique_key='customer_id') }}

{%- set as_of_ts = var('as_of_timestamp', 'current_timestamp()') %}

select
  c.customer_id,
  count_if(o.order_ts >= dateadd('day', -30, {{ as_of_ts }})) as orders_30d,
  sum(iff(o.order_ts >= dateadd('day', -30, {{ as_of_ts }}), o.total_amount, 0)) as revenue_30d,
  count_if(e.event_ts >= dateadd('day', -30, {{ as_of_ts }})) as events_30d,
  count(distinct iff(e.event_ts >= dateadd('day', -30, {{ as_of_ts }}), e.session_id, null)) as sessions_30d,
  {{ as_of_ts }} as feature_as_of_ts,
  '{{ invocation_id }}' as dbt_run_id
from {{ ref('silver_customers_current') }} c
left join {{ ref('silver_orders') }} o on c.customer_id = o.customer_id
left join {{ ref('silver_clickstream_events') }} e on c.customer_id = e.customer_id
group by 1
