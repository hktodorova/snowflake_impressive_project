provider "snowflake" {}

resource "snowflake_database" "ecommerce" {
  name    = var.database_name
  comment = "Real-time e-commerce analytics platform"
}

resource "snowflake_schema" "schemas" {
  for_each = toset(["RAW", "SILVER", "GOLD", "FEATURES", "GOVERNANCE", "OBSERVABILITY", "UTIL"])
  database = snowflake_database.ecommerce.name
  name     = each.key
}

resource "snowflake_warehouse" "warehouses" {
  for_each = {
    WH_INGEST_XS   = { size = "XSMALL", auto_suspend = 60  }
    WH_TRANSFORM_M = { size = "MEDIUM",  auto_suspend = 120 }
    WH_ANALYTICS_S = { size = "SMALL",   auto_suspend = 90  }
    WH_ML_M        = { size = "MEDIUM",  auto_suspend = 180 }
  }

  name                = each.key
  warehouse_size      = each.value.size
  auto_suspend        = each.value.auto_suspend
  auto_resume         = true
  initially_suspended = true
  comment             = "Managed by Terraform for ${var.environment}"
}

resource "snowflake_role" "roles" {
  for_each = toset([
    "ROLE_DATA_PLATFORM_ADMIN",
    "ROLE_DATA_ENGINEER",
    "ROLE_ANALYTICS_ENGINEER",
    "ROLE_BI_ANALYST",
    "ROLE_DATA_SCIENTIST",
    "ROLE_EXTERNAL_PARTNER"
  ])
  name = each.key
}
