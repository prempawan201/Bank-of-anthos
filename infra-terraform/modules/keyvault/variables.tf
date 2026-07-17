variable "name" {
  description = "Globally unique KV name (3-24 chars, alphanumeric + hyphens)"
  type        = string
}

variable "resource_group_name" {
  description = "RG holding the vault — the persistent KV env RG, not the ephemeral workload RG"
  type        = string
}

variable "location" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "tenant_id" {
  description = "Entra ID tenant ID"
  type        = string
}

# Standard everywhere. Premium only adds HSM-backed keys, which
# this secrets-only vault doesn't use.
variable "sku_name" {
  description = "KV SKU. Standard for all envs (Premium only needed for HSM-backed keys)."
  type        = string
  default     = "standard"
}

variable "purge_protection_enabled" {
  description = "true in prod (block accidental destroy); false in dev/qa for fast destroy/recreate"
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Days a deleted vault/secret is recoverable. 7 is the minimum."
  type        = number
  default     = 7
}

variable "admin_object_id" {
  description = "Object ID of the human admin granted Key Vault Administrator (required in RBAC mode to use the vault)"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "If set, creates an audit diagnostic setting. null in dev → no diagnostics."
  type        = string
  default     = null
}

# Public posture lever. Default false keeps staging/prod safe when
# they pass nothing; dev overrides to true.
variable "public_network_access_enabled" {
  description = "true = public (dev); false = private-endpoint-only (staging/prod)"
  type        = bool
  default     = false
}

# Firewall posture lever, paired with the above.
variable "network_acls_default_action" {
  description = "Allow (dev) or Deny (staging/prod). Deny = only private endpoint + trusted services."
  type        = string
  default     = "Deny"
}

variable "csi_identity_object_id" {
  description = "Object ID of the AKS KV Secrets Provider managed identity. Null skips the role assignment."
  type        = string
  default     = null
}