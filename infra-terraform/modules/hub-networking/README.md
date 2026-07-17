# hub-networking

The hub VNet at the centre of the hub-and-spoke topology — shared,
persistent infrastructure that private spokes peer into.

## When this is used
**Staging and prod only.** Dev is a standalone public VNet and does not
peer to the hub. This is part of the coupled "go private" gate.

## What it creates
- The hub resource group and VNet (`10.0.0.0/16`, tagged persistent)
- Four subnets: agent, management, and reserved Gateway/Bastion subnets
- An NSG on the agent subnet (temporary SSH-from-home, LB probes, deny-all)
- A placeholder NSG on the management subnet

## Subnet sizing decisions
| Subnet | Size | Why |
|--------|------|-----|
| `snet-agent` | /24 | Hosts the self-hosted agent VM(s). Generous headroom to scale the pool. Its range is referenced by spoke NSG rules, so it must stay stable. |
| `snet-management` | /24 | Future jumpbox/management tooling. Sized to match agent for consistency. |
| `GatewaySubnet` | /27 | **Name mandated by Azure** — VPN/ExpressRoute gateways only deploy into a subnet with this exact name. /27 is the recommended minimum. Reserved for future VPN. |
| `AzureBastionSubnet` | /26 | **Name mandated by Azure** and **/26 minimum required** — Bastion is rejected on anything smaller. Reserved for future Bastion (replaces SSH-from-home). |

Reserved subnets are parked at the top of the /16 (`.254`, `.255`) to keep
low contiguous ranges free for workload subnets to grow into.

## Why "persistent"
Spokes depend on the hub for private connectivity (peering, shared DNS via
the dns env). The hub must outlive spoke teardowns, so its RG/VNet are
tagged `lifecycle = persistent` and are never destroyed in normal cycles.
The agent VM inside it is *deallocated* (not destroyed) when idle.

## Security notes / production deltas
- `AllowSshFromHome` is a temporary single-IP SSH rule. **Remove it once
  Bastion is deployed** — that's the intended secure replacement.
- The explicit `DenyAllInbound` at priority 4096 duplicates Azure's
  implicit deny; it's kept for audit clarity, not function.
- The management NSG has no custom rules yet — tightened when tooling lands.

## Key inputs
| Variable | Purpose |
|----------|---------|
| `hub_cidr` | hub VNet block; must not overlap spokes |
| `your_home_ip` | temporary SSH source IP for the agent VM |

## Key outputs
| Output | Purpose |
|--------|---------|
| `hub_vnet_id` / `hub_vnet_name` / `hub_resource_group_name` | consumed by spoke peering |
| `agent_subnet_id` | NIC attachment for the agent VM |
| `management_subnet_id` | future management tooling |