# Hub VNet ID — consumed by spoke peering (remote_virtual_network_id).
output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

# Hub VNet name — needed by the spoke's hub_to_spoke peering, which
# is created in the hub's RG against this VNet by name.
output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

# Hub RG name — the spoke creates its reverse peering in this RG.
output "hub_resource_group_name" {
  value = azurerm_resource_group.hub.name
}

# Agent subnet ID — where the self-hosted agent VM's NIC attaches.
output "agent_subnet_id" {
  value = azurerm_subnet.agent.id
}

# Management subnet ID — for future jumpbox/management tooling.
output "management_subnet_id" {
  value = azurerm_subnet.management.id
}

# ---- Bastion outputs --------------------------------------------------------
# output "bastion_public_ip" {
#   value = azurerm_public_ip.bastion.ip_address
# }

# output "bastion_host_id" {
#   value = azurerm_bastion_host.this.id
# }