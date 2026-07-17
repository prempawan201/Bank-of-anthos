# ============================================================
# modules/log-analytics — Log Analytics Workspace
# ------------------------------------------------------------
# The central log/metric sink for the platform. Diagnostic
# settings across modules (ACR, KV, AKS Container Insights) ship
# their telemetry here.
#
# Lives in the HUB (shared, persistent) in staging/prod, so all
# environments report into one workspace. Dev does NOT deploy or
# wire this — dev passes log_analytics_workspace_id = null to every
# module, so no diagnostics are created and no LA cost is incurred.
# That's the deliberate dev cost saving: observability is a
# staging/prod concern.
# ============================================================

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  # PerGB2018 = pay-per-GB-ingested, the standard consumption model.
  sku = var.sku

  # How long data is queryable before it ages out. 30 days is the
  # included/no-extra-charge retention; longer retention bills more.
  retention_in_days = var.retention_in_days

  tags = var.common_tags
}