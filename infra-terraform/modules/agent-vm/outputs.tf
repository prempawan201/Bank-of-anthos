output "vm_id" {
  value = azurerm_linux_virtual_machine.agent.id
}

output "private_ip" {
  description = "Used by spoke NSG rules (e.g. Postgres allow-from-agent) and SSH"
  value       = azurerm_network_interface.vm.private_ip_address
}

# Principal ID for further Azure role assignments (ACR AcrPull, KV
# Secrets User for deployment work, AKS access). Source depends on mode:
#   PAT → system-assigned identity principal
#   MID → user-assigned identity principal
output "principal_id" {
  description = "VM identity principal ID — for role assignments (ACR/AKS/KV deployment access)"
  value = var.agent_auth_mode == "pat" ? azurerm_linux_virtual_machine.agent.identity[0].principal_id : azurerm_user_assigned_identity.agent[0].principal_id
}

# MID mode only: the UAMI client_id that must be pre-registered in
# the ADO org. Empty in PAT mode.
output "uami_client_id" {
  description = "MID mode: UAMI client_id to register in the Azure DevOps org. Empty in PAT mode."
  value       = var.agent_auth_mode == "managed_identity" ? azurerm_user_assigned_identity.agent[0].client_id : ""
}

output "admin_username" {
  value = var.admin_username
}