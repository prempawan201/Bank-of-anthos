# keyvault-private-endpoint

Private endpoint that gives the Key Vault a private IP inside the spoke VNet.

## When this is used
**Staging and prod only.** Dev KV is public and never calls this module.
Part of the coupled "go private" gate (private endpoint + private DNS +
self-hosted agent) — these ship together, not independently.

## What it creates
- A private endpoint in the spoke private-endpoints subnet, bound to the
  KV's `vault` subresource
- A private DNS zone group linking it into
  `privatelink.vaultcore.azure.net` so the vault hostname resolves to the
  private IP from inside the VNet

## How it fits together
1. The endpoint drops a NIC with a private IP into the PE subnet.
2. The service connection maps that IP to the Key Vault (`vault` subresource).
3. The DNS zone group makes name resolution return the private IP, so
   clients in the VNet transparently use the private path.

Connection is auto-approved (`is_manual_connection = false`) — same tenant.

## Relationship to the KV module
This PE is what makes the KV module's `network_acls_default_action = "Deny"`
posture usable: with public access off, this private path (plus the
AzureServices bypass) is how the vault is reached. Without the PE, a
Deny-default vault would be unreachable from the workload.

## Prerequisites
- The `privatelink.vaultcore.azure.net` private DNS zone must exist (dns env).
- A dedicated private-endpoints subnet must exist in the spoke.
- The Key Vault must exist (created by the keyvault module).

## Key inputs
| Variable | Purpose |
|----------|---------|
| `keyvault_id` | the vault this endpoint fronts |
| `subnet_id` | spoke private-endpoints subnet |
| `private_dns_zone_id` | privatelink.vaultcore.azure.net zone |

## Key outputs
| Output | Purpose |
|--------|---------|
| `id` | private endpoint resource ID |
| `private_ip` | assigned private IP (DNS/debug verification) |