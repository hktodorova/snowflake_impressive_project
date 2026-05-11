select
  raw_payload,
  raw_payload:customer_id::string as customer_id,
  raw_payload:email::string as email,
  raw_payload:full_name::string as full_name,
  raw_payload:country::string as country,
  raw_payload:customer_segment::string as customer_segment,
  op,
  source_lsn,
  event_ts,
  ingested_at,
  record_hash
from {{ source('raw', 'RAW_CUSTOMERS_CDC') }}
