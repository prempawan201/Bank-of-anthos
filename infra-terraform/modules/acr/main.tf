# ============================================================
# modules/acr — Azure Container Registry
# ------------------------------------------------------------
# Stores the Bank of Anthos container images that AKS pulls.
#
# Now lives INSIDE each environment's state (not a separate
# shared registry). Each env builds its own ACR:
#   dev      → Basic SKU,   public access  (hosted-agent reachable)
#   staging  → Premium SKU, private access (private endpoint)
#   prod     → Premium SKU, private access (private endpoint)
# Behaviour is driven entirely by var.sku and
# var.public_network_access_enabled — same module, both postures.
# ============================================================

resource "azurerm_container_registry" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  # SKU decides capability tier. Basic is fine for dev pulls.
  # Premium is REQUIRED in staging/prod — it's the only SKU that
  # supports private endpoints, geo-replication, and content trust.
  sku = var.sku

  # admin user is a shared username/password login — disabled
  # everywhere. AKS authenticates via its kubelet managed identity
  # (AcrPull role), which is the secretless, audited path.
  admin_enabled = false

  # true  → reachable over the public internet (dev)
  # false → reachable only via private endpoint (staging/prod)
  public_network_access_enabled = var.public_network_access_enabled

  tags = var.common_tags

  # Even when public access is off, trusted Azure services
  # (e.g. AKS image pulls, Defender scanning) bypass the firewall.
  network_rule_bypass_option = "AzureServices"
}

# ------------------------------------------------------------
# Diagnostic setting — ships ACR login + repository events and
# metrics to Log Analytics. OPTIONAL: created only when a
# workspace ID is supplied.
#   dev      → omitted (var = null) → count 0 → no diagnostics
#   staging/ → workspace passed from the hub → count 1 → logs flow
#   prod
# ------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "acr" {
  count                      = var.log_analytics_workspace_id == null ? 0 : 1
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_container_registry.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Who authenticated / pulled tokens against the registry.
  enabled_log { category = "ContainerRegistryLoginEvents" }

  # Push/pull/delete activity on repositories (image lineage).
  enabled_log { category = "ContainerRegistryRepositoryEvents" }

  # Storage used, pull counts, etc.
  metric { category = "AllMetrics" }
}