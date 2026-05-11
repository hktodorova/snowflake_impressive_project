select
  raw_payload,
  raw_payload:event_id::string as event_id,
  raw_payload:session_id::string as session_id,
  raw_payload:customer_id::string as customer_id,
  raw_payload:anonymous_id::string as anonymous_id,
  raw_payload:event_name::string as event_name,
  try_to_timestamp_ntz(raw_payload:event_ts::string) as event_ts,
  raw_payload:page_url::string as page_url,
  raw_payload:product_sku::string as product_sku,
  raw_payload:device_type::string as device_type,
  raw_payload:geo_country::string as geo_country,
  ingested_at,
  record_hash
from {{ source('raw', 'RAW_CLICKSTREAM') }}
