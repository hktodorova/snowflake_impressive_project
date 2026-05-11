select
  raw_payload,
  raw_payload:order_id::string as order_id,
  raw_payload:customer_id::string as customer_id,
  try_to_timestamp_ntz(raw_payload:order_ts::string) as order_ts,
  raw_payload:status::string as status,
  raw_payload:currency::string as currency,
  raw_payload:total_amount::number(12,2) as total_amount,
  raw_payload:payment_method::string as payment_method,
  raw_payload:shipping_country::string as shipping_country,
  source_system,
  source_file,
  ingested_at,
  record_hash
from {{ source('raw', 'RAW_ORDERS') }}
