# Snowpipe Streaming / Kafka Example

Example Kafka topic layout:

| Topic | Payload | Target table |
|---|---|---|
| ecommerce.orders | JSON | RAW.RAW_ORDERS |
| ecommerce.clickstream | JSON | RAW.RAW_CLICKSTREAM |
| ecommerce.customers_cdc | Debezium JSON | RAW.RAW_CUSTOMERS_CDC |
| ecommerce.payments | JSON | RAW.RAW_PAYMENTS |

## Connector configuration sketch

```json
{
  "name": "snowflake-ecommerce-clickstream",
  "connector.class": "com.snowflake.kafka.connector.SnowflakeSinkConnector",
  "topics": "ecommerce.clickstream",
  "snowflake.topic2table.map": "ecommerce.clickstream:RAW_CLICKSTREAM",
  "buffer.count.records": "10000",
  "buffer.flush.time": "60",
  "snowflake.ingestion.method": "SNOWPIPE_STREAMING"
}
```

Secrets should be injected through your deployment platform, not stored in this file.
