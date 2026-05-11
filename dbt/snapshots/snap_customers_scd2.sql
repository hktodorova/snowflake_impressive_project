{% snapshot snap_customers_scd2 %}

{{
    config(
        target_schema='silver',
        unique_key='customer_id',
        strategy='check',
        check_cols=['email', 'full_name', 'country', 'customer_segment'],
        invalidate_hard_deletes=true,
    )
}}

select
    customer_id,
    email,
    full_name,
    country,
    customer_segment,
    event_ts,
    ingested_at,
    {{ surrogate_key(['email', 'full_name', 'country', 'customer_segment']) }} as record_hash
from {{ ref('brz_customers_cdc') }}
where op in ('c', 'u', 'r')
  and customer_id is not null

{% endsnapshot %}
