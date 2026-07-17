# ============================================================
# modules/keyvault-private-endpoint — Private Endpoint for KV
# ------------------------------------------------------------
# Gives the Key Vault a PRIVATE IP inside the spoke VNet so
# secret access never traverses the public internet.
#
# STAGING/PROD ONLY. Dev KV is public and never calls this.
# Part of the coupled "go private" gate (private endpoint +
# private DNS + self-hosted agent) — ships as one unit.
#
# Pairs with the KV module's network_acls default_action = "Deny":
# once this PE exists, the vault is reachable only via this private
# path (plus AzureServices bypass), not the public internet.
# ============================================================

resource "azurerm_private_endpoint" "kv" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  # Dedicated private-endpoints subnet in the spoke VNet.
  subnet_id = var.subnet_id

  tags = var.common_tags

  # Binds this endpoint to the target Key Vault.
  private_service_connection {
    name = "psc-${var.name}"

    # The KV resource this endpoint fronts.
    private_connection_resource_id = var.keyvault_id

    # false = auto-approved (same tenant, we own both ends).
    is_manual_connection = false

    # "vault" is Key Vault's PE subresource (target group) — the
    # data plane (secrets/keys/certs) exposed privately.
    subresource_names = ["vault"]
  }

  # Wires the PE's private IP into the privatelink.vaultcore.azure.net
  # zone so the vault's hostname resolves to the private IP inside
  # the VNet — clients use the private path transparently.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}