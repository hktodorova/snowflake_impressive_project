{{ config(unique_key='order_id', cluster_by=['to_date(order_ts)', 'customer_id']) }}

with ranked as (
  select
    order_id,
    customer_id,
    order_ts,
    status,
    coalesce(currency, 'USD') as currency,
    total_amount,
    payment_method,
    shipping_country,
    source_system,
    ingested_at,
    row_number() over (partition by order_id order by ingested_at desc) as rn
  from {{ ref('brz_orders') }}
  where order_id is not null
  {% if is_incremental() %}
    and ingested_at >= (select dateadd('hour', -2, coalesce(max(ingested_at), '1900-01-01')) from {{ this }})
  {% endif %}
)
select * exclude rn from ranked where rn = 1
