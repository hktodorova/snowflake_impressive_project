from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "README.md",
    "docs/technical_design.md",
    "sql/00_setup/01_roles_warehouses_databases.sql",
    "sql/01_ingestion/01_raw_tables.sql",
    "sql/02_transformations/01_streams_tasks.sql",
    "sql/03_governance/01_security_governance.sql",
    "dbt/dbt_project.yml",
    "dbt/models/schema.yml",
    "terraform/main.tf",
    ".github/workflows/ci.yml",
]


def main() -> None:
    missing = [path for path in REQUIRED if not (ROOT / path).exists()]
    if missing:
        raise SystemExit(f"Missing required files: {missing}")
    forbidden = [".git", "dbt/logs", ".vscode"]
    present = [path for path in forbidden if (ROOT / path).exists()]
    if present:
        raise SystemExit(f"Forbidden directories present: {present}")
    print("Smoke test passed: required files exist and forbidden directories are absent.")


if __name__ == "__main__":
    main()
