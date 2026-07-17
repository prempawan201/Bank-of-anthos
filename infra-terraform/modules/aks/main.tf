# ============================================================
# modules/aks — Azure Kubernetes Service cluster
# ------------------------------------------------------------
# The runtime for Bank of Anthos. Drives both postures from one
# module via var.private_cluster_enabled:
#   dev      → public API server, Free tier (hosted-agent reachable)
#   staging  → private API server, private DNS, Standard tier
#   prod     → private API server, private DNS, Standard/Premium
#
# Uses a user-assigned identity (not system-assigned) so the same
# identity can be granted roles BEFORE the cluster exists, which
# is required for private-DNS and VNet operations during creation.
# ============================================================

# User-assigned identity for the cluster control plane.
# Created first so role grants below can attach to it pre-cluster.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Lets the AKS identity manage records in the private DNS zone —
# needed so a PRIVATE cluster can register its API server FQDN.
# Gated: dev passes no zone (null) → count 0 → skipped entirely.
resource "azurerm_role_assignment" "aks_private_dns" {
  count                = var.private_dns_zone_id == null ? 0 : 1
  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# Lets the AKS identity manage the spoke VNet (subnet joins, LB
# rules, route updates). Required in both postures, so NOT gated.
resource "azurerm_role_assignment" "aks_vnet_contributor" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  # Free   → no control-plane SLA (fine for dev)
  # Standard → SLA-backed control plane (staging/prod)
  sku_tier = var.sku_tier
  tags     = var.common_tags

  # Cluster creation must wait until the identity holds its roles,
  # or private-DNS/VNet operations during provisioning fail. The
  # private_dns grant may be 0 instances in dev — depends_on on an
  # empty counted resource is a safe no-op.
  depends_on = [
    azurerm_role_assignment.aks_private_dns,
    azurerm_role_assignment.aks_vnet_contributor,
  ]

  # ---- Cluster reachability posture ----
  # true  → API server only reachable inside the VNet (staging/prod)
  # false → public API endpoint (dev)
  private_cluster_enabled = var.private_cluster_enabled
  # DNS zone only applies to a private cluster; null for public dev.
  private_dns_zone_id                 = var.private_cluster_enabled ? var.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = false

  api_server_access_profile {
  authorized_ip_ranges = var.authorized_ip_ranges
  }

  # Control-plane identity (the user-assigned one created above).
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # ---- System node pool ----
  # only_critical_addons taints this pool so only system pods land
  # here; application workloads go to the user pool(s) below.
  default_node_pool {
    name                         = var.default_node_pool.name
    vm_size                      = var.default_node_pool.vm_size
    node_count                   = var.default_node_pool.node_count
    min_count                    = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.min_count : null
    max_count                    = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.max_count : null
    auto_scaling_enabled         = var.default_node_pool.auto_scaling_enabled
    os_disk_size_gb              = var.default_node_pool.os_disk_size_gb
    only_critical_addons_enabled = var.default_node_pool.only_critical_addons
    vnet_subnet_id               = var.node_subnet_id
    type                         = "VirtualMachineScaleSets"
    orchestrator_version         = var.kubernetes_version
    tags                         = var.common_tags
  }

  # ---- Networking: Azure CNI Overlay + Cilium dataplane ----
  # Overlay = pods get IPs from pod_cidr (not the VNet), conserving
  # VNet address space. Cilium provides the dataplane + NetworkPolicy.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr     # pod IPs (overlay)
    service_cidr        = var.service_cidr # ClusterIP range
    dns_service_ip      = var.dns_service_ip # kube-dns, inside service_cidr
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  # OIDC issuer + Workload Identity — lets K8s service accounts
  # federate to Entra app registrations for secretless KV access.
  # Enabled in all envs (dev keeps it on even though dev doesn't
  # wire WI yet — harmless and keeps parity).
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Auto-apply patch-level K8s upgrades.
  automatic_upgrade_channel = "patch"

  # ---- Container Insights (optional) ----
  # Created only when a Log Analytics workspace is supplied.
  # dev → null → no oms_agent block → no monitoring cost.
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id == null ? [] : [1]
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }
  key_vault_secrets_provider {
    secret_rotation_enabled = false
  }
  # Don't fight the autoscaler: ignore node_count drift so Terraform
  # doesn't reset a scaled pool back to its declared count.
  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
    ]
  }
}

# ---- User (application) node pools ----
# One pool per map entry; empty map = none. Bank of Anthos pods
# run here, away from the tainted system pool.
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = var.user_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  min_count             = each.value.auto_scaling_enabled ? each.value.min_count : null
  max_count             = each.value.auto_scaling_enabled ? each.value.max_count : null
  auto_scaling_enabled  = each.value.auto_scaling_enabled
  os_disk_size_gb       = each.value.os_disk_size_gb
  node_labels           = each.value.node_labels
  node_taints           = each.value.node_taints
  mode                  = each.value.mode
  vnet_subnet_id        = var.node_subnet_id
  orchestrator_version  = var.kubernetes_version
  tags                  = var.common_tags

  lifecycle {
    ignore_changes = [node_count]
  }
}
