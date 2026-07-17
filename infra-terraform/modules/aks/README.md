# aks

Azure Kubernetes Service cluster — the runtime for Bank of Anthos.

## When this is used
All environments. One module, two postures, driven by
`private_cluster_enabled`:

| Env | API server | Tier | Reached by |
|-----|-----------|------|------------|
| dev | public | Free | Microsoft-hosted agent, local kubectl |
| staging | private | Standard | self-hosted agent in hub |
| prod | private | Standard/Premium | self-hosted agent in hub |

## What it creates
- A user-assigned identity for the control plane
- `Network Contributor` on the spoke VNet for that identity (always)
- `Private DNS Zone Contributor` on the private DNS zone (private clusters only — gated)
- The AKS cluster with Azure CNI Overlay + Cilium dataplane
- A tainted system node pool plus zero or more user (application) node pools
- Optional Container Insights when a Log Analytics workspace is supplied

## Why user-assigned identity (not system-assigned)
The identity is created before the cluster so its role assignments
(private DNS, VNet) can be granted up front. A private cluster needs those
permissions *during* creation to register its API server FQDN and wire the
VNet — a system-assigned identity wouldn't exist yet at that point.

## Networking model
- **CNI Overlay**: pods get IPs from `pod_cidr`, not the VNet, so the VNet
  address space isn't consumed by pod scaling.
- **Cilium**: dataplane and NetworkPolicy enforcement.
- `service_cidr` / `dns_service_ip` must not overlap the VNet or `pod_cidr`.

## Cost / lifecycle
The node pool VMs are the cost. In dev the cluster is stopped at end of day
(`az aks stop`) — control plane is free on the Free tier; only running nodes
bill. `ignore_changes = [node_count]` keeps Terraform from fighting the
autoscaler.

## Posture defaults
Module defaults are production-safe: `private_cluster_enabled = true`,
`sku_tier = "Free"`. Staging/prod inherit private by passing nothing
extra; dev explicitly sets `private_cluster_enabled = false` and supplies
no `private_dns_zone_id`.

## Key inputs
| Variable | Purpose |
|----------|---------|
| `private_cluster_enabled` | public (dev) vs private (staging/prod) API |
| `private_dns_zone_id` | privatelink AKS zone; null for public dev |
| `sku_tier` | Free (dev) / Standard / Premium |
| `node_subnet_id`, `vnet_id` | spoke subnet + VNet for nodes and identity roles |
| `default_node_pool`, `user_node_pools` | system + application pools |
| `log_analytics_workspace_id` | optional Container Insights |

## Key outputs
| Output | Purpose |
|--------|---------|
| `kubelet_identity_object_id` | grant AcrPull so nodes pull images |
| `oidc_issuer_url` | trust anchor for Workload Identity |
| `private_fqdn` | private API FQDN (empty for public dev) |
| `node_resource_group` | the managed MC_* node RG |

## Version note
`kubernetes_version` is pinned via tfvars. Bump it deliberately and verify
the target is a currently AKS-supported version before applying.