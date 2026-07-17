# ============================================================
# modules/acr-private-endpoint — Private Endpoint for ACR
# ------------------------------------------------------------
# Gives the container registry a PRIVATE IP inside the spoke
# VNet, so image pulls never traverse the public internet.
#
# STAGING/PROD ONLY. Dev does not use this module — dev ACR
# is public and reached directly by the hosted agent. This is
# part of the "go private" gate (private endpoint + private
# DNS + self-hosted agent), which ships as one unit.
#
# How it fits together:
#   1. This PE drops a NIC with a private IP into the PE subnet.
#   2. That IP maps to the ACR via the "registry" subresource.
#   3. The private DNS zone (privatelink.azurecr.io) resolves
#      the registry's login server name to this private IP, so
#      clients in the VNet transparently hit the private path.
# ============================================================

resource "azurerm_private_endpoint" "acr" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  # The dedicated private-endpoints subnet in the spoke VNet.
  subnet_id = var.subnet_id

  tags = var.common_tags

  # Binds this private endpoint to the target registry.
  private_service_connection {
    name = "psc-${var.name}"

    # The ACR resource this endpoint fronts.
    private_connection_resource_id = var.acr_id

    # false = auto-approved (we own both sides, same tenant).
    # Manual approval is only for cross-tenant PE requests.
    is_manual_connection = false

    # "registry" is ACR's PE subresource (target group). It's
    # what exposes the registry data/login plane privately.
    subresource_names = ["registry"]
  }

  # Wires the PE's private IP into the private DNS zone so name
  # resolution returns the private address inside the VNet.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}