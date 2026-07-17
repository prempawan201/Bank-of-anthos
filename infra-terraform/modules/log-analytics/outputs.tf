# Workspace resource ID — passed as log_analytics_workspace_id into
# ACR/KV/AKS/Postgres modules to wire diagnostics and Container Insights.
output "id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "name" {
  value = azurerm_log_analytics_workspace.this.name
}

# The workspace GUID (distinct from resource ID) — for agents/SDKs
# that ingest by workspace ID.
output "workspace_id" {
  value = azurerm_log_analytics_workspace.this.workspace_id
}

# Primary shared key for agent ingestion. Sensitive.
output "primary_key" {
  value     = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive = true
}