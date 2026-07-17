# Server-level variables. Database/app-credential variables
# (var.databases, var.application_passwords) live in database.tf.

variable "name" {
  description = "Globally unique Postgres Flexible Server name"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "administrator_login" {
  description = "Admin username. Cannot be: admin, root, postgres, azure_superuser, administrator"
  type        = string
  default     = "pgadmin"
}

variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "Cost lever. B_Standard_B1ms (burstable, cheap) for staging practice; GP_Standard_* for prod-like."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage in MB. Minimum 32768 (32 GB)."
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Backup retention window in days."
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Geo-redundant backups. Cost lever — leave false unless practicing DR."
  type        = bool
  default     = false
}

variable "delegated_subnet_id" {
  description = "Subnet with Microsoft.DBforPostgreSQL/flexibleServers delegation. VNet integration → private server."
  type        = string
}

variable "private_dns_zone_id" {
  description = "ID of the privatelink.postgres.database.azure.com private DNS zone"
  type        = string
}

variable "key_vault_id" {
  description = "KV where admin (and per-app, in database.tf) password secrets are written"
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant ID — required for AD auth configuration"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "If set, creates diagnostics. null → none (dev)."
  type        = string
  default     = null
}