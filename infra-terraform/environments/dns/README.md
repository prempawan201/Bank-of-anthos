# dns (environment)

Shared, persistent private DNS zones — the resolution layer for private
endpoints.

## Deploys
The `private-dns` module: privatelink zones for KV, ACR, Postgres, Blob,
AKS, plus VNet links.

## Consumed by
staging/prod read `zone_ids` via remote state to wire their private
endpoints. Dev does NOT use this.

## Why dev is excluded
Dev is public (no private endpoints → nothing to resolve) and ephemeral
(destroyed nightly). Linking dev would create useless links and couple this
persistent env to a state that vanishes — the next dns apply would fail
resolving dev's VNet ID. So dns links only hub and the private spokes.

## AKS zone special case
The module links the AKS zone to hub only; each private spoke's AKS-zone
link is created by AKS itself, so adding it here would collide.

## Apply order / incremental linking
1. Apply hub.
2. Apply dns (hub link only).
3. Apply staging (creates spoke + endpoints, reading dns zone IDs).
4. Uncomment staging's remote_state + vnet_links entry, re-apply dns.
5. Repeat for prod.

Second in the overall order: hub → **dns** → dev → staging → prod.
(dev doesn't touch dns; it's in the sequence only for apply timing.)