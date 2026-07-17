# Map of zone name → zone ID. staging/prod private-endpoint modules
# look up the zone they need by name from this map via remote state.
output "zone_ids" {
  value = module.private_dns.zone_ids
}

# List of managed zone names.
output "zone_names" {
  value = module.private_dns.zone_names
}

# dns env resource group name.
output "resource_group_name" {
  value = module.private_dns.resource_group_name
}