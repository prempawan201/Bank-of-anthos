output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "spoke_vnet_name" {
  value = azurerm_virtual_network.spoke.name
}

# Workload RG name — consumed by the env root to place ACR/KV/AKS/etc.
output "resource_group_name" {
  value = azurerm_resource_group.spoke.name
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks_nodes.id
}

output "postgres_subnet_id" {
  value = azurerm_subnet.postgres.id
}

output "private_endpoints_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "ingress_subnet_id" {
  value = azurerm_subnet.ingress.id
}
