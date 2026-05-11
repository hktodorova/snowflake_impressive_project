{{ config(unique_key='event_id', cluster_by=['to_date(event_ts)', 'customer_id']) }}

with ranked as (
  select
    event_id,
    session_id,
    customer_id,
    anonymous_id,
    event_name,
    event_ts,
    page_url,
    product_sku,
    device_type,
    geo_country,
    ingested_at,
    row_number() over (partition by event_id order by ingested_at desc) as rn
  from {{ ref('brz_clickstream') }}
  where event_id is not null
  {% if is_incremental() %}
    and ingested_at >= (select dateadd('hour', -2, coalesce(max(ingested_at), '1900-01-01')) from {{ this }})
  {% endif %}
)
select * exclude rn from ranked where rn = 1
