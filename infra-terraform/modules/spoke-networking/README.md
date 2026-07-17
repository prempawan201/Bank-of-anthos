# spoke-networking

The per-environment workload network — VNet, subnets, NSGs, and (optionally)
peering to the hub.

## When this is used
All environments. One module, two postures via `enable_peering`:

| Env | Peering | Network shape |
|-----|---------|---------------|
| dev | false | standalone VNet, no hub |
| staging | true | spoke peered to hub |
| prod | true | spoke peered to hub |

Tagged `ephemeral` — this is the disposable workload tier, destroyed and
recreated freely.

## What it creates
- The workload resource group and spoke VNet
- Four subnets: `aks-nodes`, `postgres` (delegated to Flexible Server),
  `private-endpoints`, `ingress`
- An NSG per subnet with deny-all defaults plus the specific allows each
  needs
- Bidirectional hub peering — gated on `enable_peering`

## All four subnets always exist
Dev only uses the AKS subnet, but the module builds all four in every env.
Subnets and NSGs are free, so stripping them per-env isn't worth the
complexity of forking the module — keeping it identical across envs is
simpler and means dev/staging/prod differ only by input, never by code.

## How posture is decided — important
This module is **never edited per-environment** and contains **no
commented-out blocks**. Every capability is behind a variable. The
dev-vs-staging difference lives entirely in how each env's `main.tf` calls
the module:

- dev passes `enable_peering = false` and omits the hub vars
- staging/prod pass `enable_peering = true` and the hub remote-state values

Different inputs, same module, separate env folders. No commenting in/out
anywhere — that's the discipline that keeps this maintainable.

## The peering gate
`count = var.enable_peering ? 1 : 0` on both peering resources. When false
(dev), zero peering instances and the empty hub vars are never read. When
true (default), the spoke peers to the hub bidirectionally — the spoke-side
link in the spoke RG, the hub-side link in the hub RG.

## NSG model
Each subnet NSG follows allow-specific-then-deny-all:
- **aks-nodes**: allow intra-VNet, allow Azure LB probes, deny rest
- **postgres**: allow 5432 from AKS subnet and from the hub agent subnet
  (admin access), allow outbound to VNet + Storage (WAL/backups), deny rest
- **private-endpoints**: allow 443 from AKS subnet, deny rest
- **ingress**: placeholder, tightened in PLAT-5

The explicit `DenyAllInbound` at priority 4096 duplicates Azure's implicit
deny for audit clarity.

## Production deltas
- The Postgres NSG's `AllowAgentToPostgres` rule hardcodes the hub agent
  CIDR (`10.0.1.0/24`). Replace with a tightly-scoped Bastion rule in prod.
- The ingress NSG has no real rules yet (PLAT-5).

## Key inputs
| Variable | Purpose |
|----------|---------|
| `enable_peering` | standalone (dev) vs hub-peered (staging/prod) |
| `spoke_cidr`, `subnet_cidrs` | VNet and subnet address space |
| `hub_vnet_id` / `hub_vnet_name` / `hub_resource_group_name` | peering targets (empty in dev) |

## Key outputs
| Output | Purpose |
|--------|---------|
| `resource_group_name` | workload RG, consumed by ACR/KV/AKS placement |
| `aks_subnet_id` | AKS node placement |
| `postgres_subnet_id` | delegated subnet for Flexible Server |
| `private_endpoints_subnet_id` | PE placement (staging/prod) |
| `ingress_subnet_id` | ingress controller (PLAT-5) |
| `spoke_vnet_id` / `spoke_vnet_name` | peering and DNS links |