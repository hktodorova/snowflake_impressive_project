{{ config(unique_key='customer_id') }}

with ranked as (
  select
    customer_id,
    email,
    full_name,
    country,
    customer_segment,
    event_ts,
    ingested_at,
    {{ surrogate_key(['email', 'full_name', 'country', 'customer_segment']) }} as record_hash,
    row_number() over (partition by customer_id order by coalesce(event_ts, ingested_at) desc) as rn
  from {{ ref('brz_customers_cdc') }}
  where op in ('c', 'u', 'r') and customer_id is not null
)
select * exclude rn from ranked where rn = 1
