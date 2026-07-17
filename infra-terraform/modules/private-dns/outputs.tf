# Map of zone name → zone ID. This is the key output: the
# private-endpoint modules (acr-pe, kv-pe, postgres) look up the
# zone they need by name from this map, and AKS gets its zone ID
# the same way.
output "zone_ids" {
  description = "Map of zone name to zone ID"
  value       = { for k, z in azurerm_private_dns_zone.zones : k => z.id }
}

# The list of zone names managed here.
output "zone_names" {
  value = local.zones
}

# DNS env RG name.
output "resource_group_name" {
  value = azurerm_resource_group.dns.name
}