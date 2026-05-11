"""Snowpark feature engineering job — customer 30-day behaviour features.

Author: Hristina Todorova <hktodorova@gmail.com>
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, count, count_distinct, dateadd, iff, lit, sum as sf_sum


def build_customer_behavior_features(
    session: Session,
    as_of_timestamp: datetime | None = None,
    run_id: str | None = None,
) -> None:
    """Compute 30-day customer behaviour features.

    Parameters
    ----------
    as_of_timestamp:
        Point-in-time cutoff for the 30-day window. Defaults to the current
        UTC time, but can be overridden for historical backfills or ML replay.
    run_id:
        Unique identifier for this pipeline run. Stored in the output table
        so downstream models can trace features back to a specific execution.
    """
    as_of_ts: datetime = as_of_timestamp or datetime.now(timezone.utc)
    run_id = run_id or str(uuid.uuid4())
    as_of_lit = lit(as_of_ts)
    cutoff_lit = lit(as_of_ts.replace(tzinfo=None))  # Snowflake TIMESTAMP_NTZ

    orders = session.table("ECOMMERCE_RT.SILVER.ORDERS")
    events = session.table("ECOMMERCE_RT.SILVER.CLICKSTREAM_EVENTS")
    customers = session.table("ECOMMERCE_RT.SILVER.CUSTOMERS_SCD2").filter(col("IS_CURRENT") == True)

    orders_30d = (
        orders.filter(col("ORDER_TS") >= dateadd("day", -30, cutoff_lit))
        .group_by("CUSTOMER_ID")
        .agg(count("ORDER_ID").alias("ORDERS_30D"), sf_sum("TOTAL_AMOUNT").alias("REVENUE_30D"))
    )

    events_30d = (
        events.filter(col("EVENT_TS") >= dateadd("day", -30, cutoff_lit))
        .group_by("CUSTOMER_ID")
        .agg(count("EVENT_ID").alias("EVENTS_30D"), count_distinct("SESSION_ID").alias("SESSIONS_30D"))
    )

    features = (
        customers.select("CUSTOMER_ID")
        .join(orders_30d, "CUSTOMER_ID", "left")
        .join(events_30d, "CUSTOMER_ID", "left")
        .select(
            col("CUSTOMER_ID"),
            iff(col("ORDERS_30D").is_null(), 0, col("ORDERS_30D")).alias("ORDERS_30D"),
            iff(col("REVENUE_30D").is_null(), 0, col("REVENUE_30D")).alias("REVENUE_30D"),
            iff(col("EVENTS_30D").is_null(), 0, col("EVENTS_30D")).alias("EVENTS_30D"),
            iff(col("SESSIONS_30D").is_null(), 0, col("SESSIONS_30D")).alias("SESSIONS_30D"),
            as_of_lit.alias("FEATURE_AS_OF_TS"),
            lit(run_id).alias("RUN_ID"),
        )
    )

    features.write.mode("overwrite").save_as_table("ECOMMERCE_RT.FEATURES.CUSTOMER_BEHAVIOR_30D")
