# Networking
output "spoke_vnet_id" { value = module.spoke_networking.spoke_vnet_id }
output "aks_subnet_id" { value = module.spoke_networking.aks_subnet_id }

# ACR
output "acr_id" { value = module.acr.id }
output "acr_login_server" { value = module.acr.login_server }

# Key Vault
output "keyvault_id" { value = module.keyvault.id }
output "keyvault_uri" { value = module.keyvault.uri }
output "keyvault_name" { value = module.keyvault.name }

# AKS
output "aks_id" { value = module.aks.id }
output "aks_name" { value = module.aks.name }
output "aks_kubelet_identity" { value = module.aks.kubelet_identity_object_id }
output "aks_oidc_issuer_url" { value = module.aks.oidc_issuer_url }
output "aks_node_resource_group" { value = module.aks.node_resource_group }

# Logging
output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.dev.workspace_id
}

output "log_analytics_workspace_key" {
  value     = azurerm_log_analytics_workspace.dev.primary_shared_key
  sensitive = true
}

# Alert Management
output "monitor_alert_id" {
  value = azurerm_monitor_scheduled_query_rules_alert_v2.boa_error_logs.id
}