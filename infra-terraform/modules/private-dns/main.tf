# ============================================================
# modules/private-dns — Private DNS zones (shared, persistent)
# ------------------------------------------------------------
# STAGING/PROD ONLY. The shared DNS env that makes private
# endpoints resolvable. Each privatelink zone maps a service's
# public hostname to its private endpoint IP inside the VNet, so
# clients reach KV/ACR/Postgres/AKS over the private path using
# the normal hostnames.
#
# Persistent, lives in its own env (rg-boa-dns-eus2) and is read
# by spokes via remote state — like the hub env. Dev does not use
# this (dev is public, no private endpoints, no DNS zones).
#
# This is the resolution half of the "go private" gate; the
# private-endpoint modules are the connectivity half.
# ============================================================

locals {
  # One privatelink zone per private service in the platform.
  # The zone name MUST match Azure's required privatelink suffix
  # for that service — these are not arbitrary.
  zones = [
    "privatelink.vaultcore.azure.net",          # Key Vault
    "privatelink.azurecr.io",                    # Container Registry
    "privatelink.postgres.database.azure.com",   # Postgres Flexible Server
    "privatelink.blob.core.windows.net",         # Blob (e.g. TF state, backups)
    "privatelink.eastus2.azmk8s.io",             # AKS API server (region-specific)
  ]

  # Build the set of (zone, vnet) links to create — the cartesian
  # product of every zone against every VNet in var.vnet_links,
  # EXCEPT one special case for the AKS zone.
  #
  # THE AKS SPECIAL CASE (the `if` filter):
  # When a PRIVATE AKS cluster is created with a custom private DNS
  # zone, AKS itself creates the VNet link from that zone to the
  # cluster's own spoke VNet — Terraform doesn't own that link.
  # If Terraform also tried to link the AKS zone to a spoke
  # (dev/qa/prod), the apply would collide with the link AKS
  # already made and fail.
  #
  # So: the AKS zone (privatelink.eastus2.azmk8s.io) is linked ONLY
  # to "hub". Every spoke gets its AKS-zone link created by AKS,
  # not here. All OTHER zones link to every VNet normally.
  #
  # The filter reads: "drop any pair where the zone is the AKS zone
  # AND the vnet is not hub." Everything else is kept.
  zone_vnet_pairs = {
    for pair in setproduct(local.zones, keys(var.vnet_links)) :
    "${pair[0]}--${pair[1]}" => {
      zone_name = pair[0]
      vnet_name = pair[1]
      vnet_id   = var.vnet_links[pair[1]]
    }
    if !(pair[0] == "privatelink.eastus2.azmk8s.io" && pair[1] != "hub")
  }
}

resource "azurerm_resource_group" "dns" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.common_tags
}

# One private DNS zone per entry in local.zones.
resource "azurerm_private_dns_zone" "zones" {
  for_each            = toset(local.zones)
  name                = each.key
  resource_group_name = azurerm_resource_group.dns.name
  tags                = var.common_tags
}

# Link each zone to the appropriate VNet(s) per the filtered map
# above. registration_enabled = false because these zones are for
# RESOLUTION of private endpoints, not auto-registration of VM
# hostnames — PE records are created by the private endpoints, not
# by VNet auto-registration.
resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each = local.zone_vnet_pairs

  name                  = "link-${each.value.vnet_name}"
  resource_group_name   = azurerm_resource_group.dns.name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.value.zone_name].name
  virtual_network_id    = each.value.vnet_id
  registration_enabled  = false
}