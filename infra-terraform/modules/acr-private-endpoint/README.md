# acr-private-endpoint

Private endpoint that gives the container registry a private IP inside the
spoke VNet.

## When this is used
**Staging and prod only.** Dev ACR is public and never calls this module.
Part of the coupled "go private" gate (private endpoint + private DNS +
self-hosted agent) — these ship together, not independently.

## What it creates
- A private endpoint in the spoke private-endpoints subnet, bound to the
  ACR's `registry` subresource
- A private DNS zone group linking the endpoint into
  `privatelink.azurecr.io` so the registry's login server resolves to the
  private IP from inside the VNet

## How it fits together
1. The endpoint drops a NIC with a private IP into the PE subnet.
2. The service connection maps that IP to the ACR (`registry` subresource).
3. The DNS zone group makes name resolution return the private IP, so
   clients in the VNet transparently use the private path.

Connection is auto-approved (`is_manual_connection = false`) because both
sides are in the same tenant.

## Prerequisites
- ACR must be Premium SKU (private endpoints unsupported on Basic/Standard).
- The `privatelink.azurecr.io` private DNS zone must exist (shared dns env).
- A dedicated private-endpoints subnet must exist in the spoke.

## Key inputs
| Variable | Purpose |
|----------|---------|
| `acr_id` | the registry this endpoint fronts |
| `subnet_id` | spoke private-endpoints subnet |
| `private_dns_zone_id` | privatelink.azurecr.io zone |

## Key outputs
| Output | Purpose |
|--------|---------|
| `id` | private endpoint resource ID |
| `private_ip` | assigned private IP (DNS/debug verification) |