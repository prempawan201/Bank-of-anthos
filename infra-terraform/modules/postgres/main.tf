# ============================================================
# modules/postgres/main.tf
# ------------------------------------------------------------
# The Flexible Server itself, its admin credential, server-level
# configuration, and diagnostics. The databases and per-app
# credentials live in database.tf.
#
# STAGING/PROD ONLY. VNet-integrated (private) server —
# delegated_subnet_id + private_dns_zone_id make it reachable
# only inside the VNet, a model mutually exclusive with public
# access. Dev does not deploy this module.
#
# Admin password is generated here and written to Key Vault;
# nothing hand-fed, regenerated automatically on recreate.
# ============================================================

# ---- Admin password ----
# Stronger complexity floor than the per-app passwords (explicit
# min counts per character class).
resource "random_password" "admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# Store the admin password in Key Vault with a 1-year expiry.
resource "azurerm_key_vault_secret" "admin_password" {
  name         = "postgres-admin-password"
  value        = random_password.admin.result
  key_vault_id = var.key_vault_id
  content_type = "text/plain"
  # timestamp() re-evaluates each plan so this date drifts every
  # run — neutralized by ignore_changes below, so no churn after
  # first create. Known-and-handled, not a bug.
  expiration_date = timeadd(timestamp(), "8760h") # 1 year

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

# ---- The Flexible Server ----
resource "azurerm_postgresql_flexible_server" "this" {
  name                   = var.name
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = var.postgres_version
  administrator_login    = var.administrator_login
  administrator_password = random_password.admin.result
  storage_mb             = var.storage_mb
  sku_name               = var.sku_name
  backup_retention_days  = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  # VNet integration — joins the delegated subnet and registers in
  # the private DNS zone. This is what makes the server private and
  # is incompatible with public access by design.
  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.private_dns_zone_id
  tags                = var.common_tags

  # Always private. NOT a variable — the delegated-subnet model
  # above forbids public access; the two cannot coexist.
  public_network_access_enabled = false

  # Dual auth: Entra AD (preferred) + password (for app connection
  # strings using the KV-stored passwords).
  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
    tenant_id                     = var.tenant_id
  }

  # Patch in a low-traffic window.
  maintenance_window {
    day_of_week  = 0 # Sunday
    start_hour   = 2 # 2am UTC
    start_minute = 0
  }

  lifecycle {
    # Don't fight Azure's availability-zone placement on HA.
    ignore_changes = [
      zone,
      high_availability[0].standby_availability_zone,
    ]
  }
}

# ---- Server configurations (postgresql.conf equivalents) ----

# Throttle connections from abusive clients.
resource "azurerm_postgresql_flexible_server_configuration" "connection_throttling" {
  name      = "connection_throttle.enable"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "on"
}

# Log checkpoint activity (tuning / diagnostics).
resource "azurerm_postgresql_flexible_server_configuration" "log_checkpoints" {
  name      = "log_checkpoints"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "on"
}

# Log every connection (audit trail).
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "on"
}

# ⚠ NAME/VALUE MISMATCH — resource is named "pgaadauth" (implying
# the Azure AD auth extension) but the value loads only pgcrypto +
# pg_stat_statements; pgaadauth is NOT included, while AD auth is
# enabled on the server above. DECIDE:
#   - want AD auth ext loaded → value = "pgaadauth,pgcrypto,pg_stat_statements"
#   - only crypto+stats intended → rename resource to "pg_extensions"
# Left unchanged pending your call.
resource "azurerm_postgresql_flexible_server_configuration" "pgaadauth" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "pgcrypto,pg_stat_statements"
}

# ---- Diagnostics (optional) ----
# null in any env that doesn't pass a workspace → count 0.
resource "azurerm_monitor_diagnostic_setting" "postgres" {
  count                      = var.log_analytics_workspace_id == null ? 0 : 1
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_postgresql_flexible_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "PostgreSQLLogs" }
  enabled_log { category = "PostgreSQLFlexSessions" }
  enabled_log { category = "PostgreSQLFlexQueryStoreRuntime" }

  metric { category = "AllMetrics" }
}