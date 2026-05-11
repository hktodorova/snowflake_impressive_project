# Terraform

This is an intentionally compact IaC skeleton. In a real enterprise rollout, split it into modules:

- roles and role hierarchy
- databases and schemas
- warehouses and resource monitors
- stages and integrations
- grants
- policies and tags

Configure the Snowflake provider using environment variables or your secret manager. Do not commit credentials.
