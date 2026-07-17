# ============================================================
# modules/postgres/database.tf
# ------------------------------------------------------------
# The databases and per-application credentials that sit ON the
# Flexible Server (the server itself is in main.tf). Split out so
# the "what apps and DBs exist" concern is separate from the
# server provisioning concern.
#
# Bank of Anthos splits its data across two databases (accounts,
# ledger), each accessed by its own service with its own password.
# ============================================================

# Which databases to create, with their collation/charset.
# Defaulted to the two Bank of Anthos databases.
variable "databases" {
  description = "Map of database names to their collation/charset settings"
  type = map(object({
    collation = string
    charset   = string
  }))
  default = {
    accounts = { collation = "en_US.utf8", charset = "UTF8" }
    ledger   = { collation = "en_US.utf8", charset = "UTF8" }
  }
}

# Which app services each need their own distinct Postgres password
# stored in Key Vault. A set, not a map — just names; the password
# itself is generated below.
variable "application_passwords" {
  description = "Set of application names each requiring their own KV-stored Postgres password"
  type        = set(string)
  default     = ["accounts-svc", "ledger-svc"]
}

# One database per entry in var.databases, created on the server
# defined in main.tf.
resource "azurerm_postgresql_flexible_server_database" "this" {
  for_each  = var.databases
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.this.id
  collation = each.value.collation
  charset   = each.value.charset

  lifecycle {
    # false for learning (fast destroy/recreate).
    # PRODUCTION DELTA: true to block accidental DB deletion.
    prevent_destroy = false
  }
}

# One random password per app service — distinct credential each,
# so a leak of one service's password doesn't expose the others.
resource "random_password" "app" {
  for_each         = var.application_passwords
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

# Store each app password in Key Vault as postgres-<app>-password.
# Apps read these at runtime rather than holding hardcoded creds.
# Regenerated and rewritten automatically on recreate — nothing
# hand-fed.
resource "azurerm_key_vault_secret" "app_password" {
  for_each     = var.application_passwords
  name         = "postgres-${each.key}-password"
  value        = random_password.app[each.key].result
  key_vault_id = var.key_vault_id
  content_type = "text/plain"

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

# Map of created database name → name (confirmation/reference).
output "database_names" {
  value = { for k, v in azurerm_postgresql_flexible_server_database.this : k => v.name }
}

# Map of app name → KV secret ID, so the environment root can wire
# each service to its own credential.
output "app_password_secret_ids" {
  description = "Map of app name to KV secret ID for its Postgres password"
  value       = { for k, v in azurerm_key_vault_secret.app_password : k => v.id }
}