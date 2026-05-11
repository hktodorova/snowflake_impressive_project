from __future__ import annotations

import csv
import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
OUT = BASE / "sample_data"
OUT.mkdir(exist_ok=True)

random.seed(42)

countries = ["US", "CA", "GB", "DE", "FR", "BG"]
segments = ["new", "standard", "vip", "at_risk"]
events = ["page_view", "product_view", "add_to_cart", "checkout", "search"]
products = [f"SKU-{i:04d}" for i in range(1, 51)]
now = datetime.now(timezone.utc).replace(microsecond=0)

customers = []
for i in range(1, 101):
    customers.append(
        {
            "customer_id": f"C{i:05d}",
            "email": f"customer{i}@example.com",
            "full_name": f"Customer {i}",
            "country": random.choice(countries),
            "customer_segment": random.choice(segments),
        }
    )

orders = []
for i in range(1, 501):
    customer = random.choice(customers)
    order_ts = now - timedelta(days=random.randint(0, 60), minutes=random.randint(0, 1440))
    orders.append(
        {
            "order_id": f"O{i:07d}",
            "customer_id": customer["customer_id"],
            "order_ts": order_ts.isoformat(),
            "status": random.choice(["paid", "shipped", "completed", "cancelled"]),
            "currency": "USD",
            "total_amount": round(random.uniform(10, 1500), 2),
            "payment_method": random.choice(["card", "paypal", "apple_pay", "bank_transfer"]),
            "shipping_country": random.choice(countries),
        }
    )

clicks = []
for i in range(1, 1501):
    customer = random.choice(customers + [None] * 2)
    event_ts = now - timedelta(days=random.randint(0, 30), minutes=random.randint(0, 1440))
    clicks.append(
        {
            "event_id": f"E{i:08d}",
            "session_id": f"S{random.randint(1, 350):06d}",
            "customer_id": customer["customer_id"] if customer else None,
            "anonymous_id": f"A{random.randint(1, 1000):06d}",
            "event_name": random.choice(events),
            "event_ts": event_ts.isoformat(),
            "page_url": f"/products/{random.choice(products)}",
            "product_sku": random.choice(products),
            "device_type": random.choice(["web", "ios", "android"]),
            "geo_country": random.choice(countries),
        }
    )

with (OUT / "orders.json").open("w", encoding="utf-8") as f:
    for row in orders:
        f.write(json.dumps(row) + "\n")

with (OUT / "clickstream.json").open("w", encoding="utf-8") as f:
    for row in clicks:
        f.write(json.dumps(row) + "\n")

with (OUT / "customers_cdc.json").open("w", encoding="utf-8") as f:
    for row in customers:
        f.write(json.dumps({**row, "op": "r", "event_ts": now.isoformat()}) + "\n")

with (OUT / "partner_products.csv").open("w", encoding="utf-8", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["partner_id", "product_sku", "category", "brand", "list_price"])
    writer.writeheader()
    for sku in products:
        writer.writerow(
            {
                "partner_id": "P001",
                "product_sku": sku,
                "category": random.choice(["electronics", "home", "fashion", "beauty"]),
                "brand": random.choice(["Northstar", "Acme", "Zenith", "Orbit"]),
                "list_price": round(random.uniform(5, 1200), 2),
            }
        )

print(f"Generated sample files in {OUT}")
