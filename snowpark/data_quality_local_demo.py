from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

BASE = Path(__file__).resolve().parents[1]
DATA = BASE / "sample_data"


def read_json_lines(path: Path) -> pd.DataFrame:
    records = []
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                records.append(json.loads(line))
    return pd.DataFrame(records)


def check_orders(df: pd.DataFrame) -> pd.DataFrame:
    checks = [
        {"check_name": "orders_total_rows", "value": len(df), "status": "INFO"},
        {"check_name": "orders_duplicate_order_ids", "value": int(df["order_id"].duplicated().sum()), "status": "PASS" if df["order_id"].duplicated().sum() == 0 else "FAIL"},
        {"check_name": "orders_null_critical_fields", "value": int(df[["order_id", "customer_id", "order_ts", "total_amount"]].isna().sum().sum()), "status": "PASS" if df[["order_id", "customer_id", "order_ts", "total_amount"]].isna().sum().sum() == 0 else "FAIL"},
        {"check_name": "orders_negative_amount", "value": int((df["total_amount"] < 0).sum()), "status": "PASS" if (df["total_amount"] < 0).sum() == 0 else "FAIL"},
    ]
    return pd.DataFrame(checks)


def main() -> None:
    orders_path = DATA / "orders.json"
    if not orders_path.exists():
        raise FileNotFoundError("Run scripts/generate_sample_data.py first")
    orders = read_json_lines(orders_path)
    result = check_orders(orders)
    print(result.to_string(index=False))


if __name__ == "__main__":
    main()
