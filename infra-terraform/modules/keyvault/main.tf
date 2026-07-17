# ============================================================
# modules/keyvault — Azure Key Vault
# ------------------------------------------------------------
# Stores secrets (Postgres passwords, and in staging the ADO
# agent PAT). RBAC-authorized, not access-policy based.
#
# One module, two postures:
#   dev      → Standard, public, ACL default Allow
#   staging  → Standard, private (PE), ACL default Deny
#   prod     → Standard, private (PE), ACL default Deny
# SKU is Standard everywhere — Premium only buys HSM-backed
# KEYS, and this vault holds secrets, not HSM key material.
#
# Lifecycle: lives in its OWN env folder (dev-keyvault/), given
# its own persistent state and RG, so the nightly destroy of the
# ephemeral workload env never deletes it. Consumers read it via
# remote state.
# ============================================================

resource "azurerm_key_vault" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name
  tags                = var.common_tags

  # RBAC mode (not access policies) — permissions are granted via
  # Azure role assignments, consistent with the rest of the platform.
  enable_rbac_authorization = true

  # Public posture lever:
  #   dev      → true  (hosted agent + local reach it directly)
  #   staging/ → false (private-endpoint-only)
  #   prod
  public_network_access_enabled = var.public_network_access_enabled

  # purge protection off in dev/qa so a vault can be fully purged
  # and recreated; on in prod to prevent accidental destruction.
  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days

  # Network firewall:
  #   dev      → default_action Allow (any public IP, still RBAC-gated)
  #   staging/ → default_action Deny  (only private endpoint / trusted)
  #   prod
  # AzureServices bypass lets trusted Azure platform services through
  # even under Deny.
  network_acls {
    default_action = var.network_acls_default_action
    bypass         = "AzureServices"
  }
}

# Grants the human operator full data-plane control (read/write
# secrets, keys, certs). In RBAC mode this role is what lets you
# actually use the vault — without a role assignment even the
# creator can't read secrets.
resource "azurerm_role_assignment" "admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.admin_object_id
}

# Grants the AKS KV Secrets Provider (CSI driver) identity read
# access to secrets — allows pods to mount secrets directly from
# Key Vault via the CSI driver without pipeline intervention.
# principal_id is the CSI driver's managed identity object ID,
# passed in from the environment root after AKS is created.
resource "azurerm_role_assignment" "csi_secrets_user" {
  count                = var.csi_identity_object_id == null ? 0 : 1
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.csi_identity_object_id
  principal_type       = "ServicePrincipal"
}

# Optional audit logging to Log Analytics. Created only when a
# workspace is supplied (dev → null → count 0 → no diagnostics).
# AuditEvent captures every secret access — the audit trail a
# bank would require in staging/prod.
resource "azurerm_monitor_diagnostic_setting" "kv" {
  count                      = var.log_analytics_workspace_id == null ? 0 : 1
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "AuditEvent" }                  # every secret/key access
  enabled_log { category = "AzurePolicyEvaluationDetails" } # policy compliance events

  metric { category = "AllMetrics" }
}