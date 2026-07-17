# ============================================================
# environments/dev/main.tf
# ------------------------------------------------------------
# Reconstructed from terraform state (main.tf was lost).
# Dev environment — public, cheap, ephemeral. Single state file.
# Manages: networking, ACR, Key Vault, AKS, and the root-level
# role assignments that wire them together.
#
# Apply order (implicit via depends_on / references):
#   1. spoke_networking  — VNet + subnets (AKS needs subnet ID)
#   2. acr + keyvault    — parallel, no dependency between them
#   3. aks               — needs VNet ID + subnet ID from step 1
#   4. role assignments  — need AKS kubelet identity + CSI identity + ACR/KV IDs
#   5. time_sleep(s)     — gate anything reading KV / assigning roles
#                           to just-created identities after their grant
# ============================================================

# ---- Networking ------------------------------------------------
# Owns the resource group in dev (ADR-043: module-owned RG).
# Produces spoke_vnet_id + aks_subnet_id consumed by AKS below.
# enable_peering = false → standalone dev VNet, no hub peering
# (ADR-039). The hub_* args are unused when peering is off.
module "spoke_networking" {
  source              = "../../modules/spoke-networking"
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  spoke_cidr          = var.spoke_cidr
  subnet_cidrs        = var.subnet_cidrs
  common_tags         = var.common_tags
  enable_peering      = false
  enable_public_http_ingress = true ## plat 9.2 fix: public ingress in dev
}

# ---- ACR -------------------------------------------------------
# Basic SKU — cheapest tier, sufficient for dev image storage.
# Public network access on in dev — no private endpoint (ADR-039).
# admin_enabled is hardcoded false inside the module (fail-closed).
module "acr" {
  source              = "../../modules/acr"
  name                = var.acr_name
  location            = var.location
  resource_group_name = module.spoke_networking.resource_group_name
  sku                 = "Basic"
  common_tags         = var.common_tags
}

# ---- Key Vault -------------------------------------------------
# RBAC mode (enable_rbac_authorization = true in the module).
# Public network access on in dev — no private endpoint.
# purge_protection off so the vault can be destroyed and
# recreated without a 90-day soft-delete wait.
#
# NOTE: csi_identity_object_id was REMOVED from this module call
# (PLAT debug session — PrincipalNotFound after 30m hang). The
# module no longer grants that role internally; it is granted at
# root below, gated by time_sleep.wait_for_csi_identity, because
# only the root has visibility into both module.aks and
# module.keyvault to express the ordering dependency.
module "keyvault" {
  source              = "../../modules/keyvault"
  name                = var.keyvault_name
  location            = var.location
  resource_group_name = module.spoke_networking.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"
  admin_object_id     = var.admin_object_id

  public_network_access_enabled = true
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
  network_acls_default_action   = "Allow"

  common_tags = var.common_tags
}

# ---- AKS -------------------------------------------------------
# Free tier — no control-plane SLA, fine for dev.
# Public API server (private_cluster_enabled = false) so
# Microsoft-hosted pipeline agents can reach it.
# CNI Overlay + Cilium declared in module.
# key_vault_secrets_provider block declared in module (PLAT-9) —
# this is what creates the CSI addon managed identity that the
# role assignment below grants KV access to.
module "aks" {
  source              = "../../modules/aks"
  name                = var.aks_name
  location            = var.location
  resource_group_name = module.spoke_networking.resource_group_name
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  # Public posture — no private DNS zone needed in dev.
  private_cluster_enabled = false
  private_dns_zone_id     = null

  # Networking — references spoke_networking outputs.
  vnet_id        = module.spoke_networking.spoke_vnet_id
  node_subnet_id = module.spoke_networking.aks_subnet_id

  # CIDR blocks — verified from state. Must match exactly or
  # Terraform will attempt to recreate the cluster.
  pod_cidr       = "10.244.0.0/16"
  service_cidr   = "172.16.0.0/16"
  dns_service_ip = "172.16.0.10"

  # System node pool — only_critical_addons = true taints this
  # pool so only system pods land here. App workloads go to
  # the workload user pool below. Verified from state.
  default_node_pool = {
    name                 = "system"
    vm_size              = "Standard_D2as_v6"
    node_count           = 1
    auto_scaling_enabled = true
    min_count            = 1
    max_count            = 3
    os_disk_size_gb      = 50
    only_critical_addons = true
  }

  # User (application) node pool — Bank of Anthos pods run here.
  # node_labels verified from state: workload=apps.
  user_node_pools = {
    workload = {
      vm_size              = "Standard_D2as_v6"
      node_count           = 1
      auto_scaling_enabled = true
      min_count            = 1
      max_count            = 3
      os_disk_size_gb      = 50
      node_labels          = { "workload" = "apps" }
      node_taints          = []
      mode                 = "User"
    }
  }

  # No Log Analytics in dev — saves cost (ADR-039).
  log_analytics_workspace_id = null

  common_tags = var.common_tags
}

# ---- Kubelet AcrPull -------------------------------------------
# Grants the AKS kubelet identity pull access to ACR so pods
# pull images without imagePullSecret. The node itself
# authenticates to ACR using this role.
resource "azurerm_role_assignment" "aks_kubelet_acrpull" {
  principal_id         = module.aks.kubelet_identity_object_id
  role_definition_name = "AcrPull"
  scope                = module.acr.id

  depends_on = [module.aks, module.acr]
}

# ---- CSI Secrets Provider identity → KV Secrets User ------------
# Grants the AKS CSI Secrets Store addon's managed identity
# Key Vault Secrets User, so pods can mount KV secrets directly
# via the CSI driver (PLAT-9, ADR-029).
#
# THIS IS NOT THE KUBELET IDENTITY — the CSI addon provisions its
# own separate managed identity as part of the AKS cluster resource
# (key_vault_secrets_provider block). module.aks must expose it as
# an output; see Code Breakdown below for the required output shape.
#
# principal_type is set explicitly to skip the provider's own
# pre-flight AAD existence check, which is the exact check that
# fails during Entra replication lag on a freshly-minted identity.
resource "azurerm_role_assignment" "csi_secrets_user" {
  principal_id         = module.aks.key_vault_secrets_provider_object_id   # ← corrected
# principal_id         = module.aks.csi_secrets_provider_identity_object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = module.keyvault.id
  principal_type        = "ServicePrincipal"

  depends_on = [time_sleep.wait_for_csi_identity]
}

# ---- CSI identity replication wait -------------------------------
# ARM reports the AKS cluster (and its CSI addon identity) as
# created the instant azurerm_kubernetes_cluster.this returns, but
# Entra ID's directory read path lags behind that — sometimes by
# several minutes. Any role assignment against a same-apply-created
# identity issued before replication completes 400s with
# PrincipalNotFound. This wait absorbs that lag.
# Debugged 2026-07-02: role assignment hung 30m then failed without it.
resource "time_sleep" "wait_for_csi_identity" {
  depends_on      = [module.aks]
  create_duration = "60s"
}

# ---- Pipeline KV Secrets Officer -------------------------------
# Grants the pipeline SP (sc-boa-dev) write access to KV secrets
# so the CD pipeline can create/update secrets.
# Secrets Officer = read + write secrets only (not keys/certs).
resource "azurerm_role_assignment" "pipeline_kv_secrets_officer" {
  principal_id         = var.platform_sp_object_id
  role_definition_name = "Key Vault Secrets Officer"
  scope                = module.keyvault.id

  depends_on = [module.keyvault]
}

# ---- RBAC propagation wait -------------------------------------
# Entra role assignments take up to 120s to propagate globally.
# Anything that reads KV immediately after the grant above would
# get a 403 without this wait. Verified from state: 120s.
resource "time_sleep" "wait_for_kv_rbac" {
  depends_on      = [azurerm_role_assignment.pipeline_kv_secrets_officer]
  create_duration = "120s"
}

#---- Logging ---------------------------------------------------
resource "azurerm_log_analytics_workspace" "dev" {
  name                = "law-boa-dev-eus2"
  location            = var.location
  resource_group_name = module.spoke_networking.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

#---- Alert Management ---------------------------------------------------
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "boa_error_logs" {
  name                = "boa-error-logs-dev"
  resource_group_name = module.spoke_networking.resource_group_name
  location            = var.location

  description          = "Fires when BoA services log more than 10 errors in a 5-minute window"
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.dev.id]
  severity             = 2
  enabled              = true

  criteria {
    query = <<-QUERY
      boa_container_logs_CL
      | where log_s contains "ERROR" or log_s contains "Exception"
      | where kubernetes_namespace_name_s == "boa"
      | summarize ErrorCount = count() by bin(TimeGenerated, 5m)
      | where ErrorCount > 10
    QUERY

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  # No action group in dev — alert fires and is visible in Azure Monitor Alerts blade.
  # Staging/prod: wire action_groups to an azurerm_monitor_action_group resource.
}


# # ============================================================
# # environments/dev/main.tf
# # ------------------------------------------------------------
# # Reconstructed from terraform state (main.tf was lost).
# # Dev environment — public, cheap, ephemeral. Single state file.
# # Manages: networking, ACR, Key Vault, AKS, and the three
# # root-level role assignments that wire them together.
# #
# # Apply order (implicit via depends_on / references):
# #   1. spoke_networking  — VNet + subnets (AKS needs subnet ID)
# #   2. acr + keyvault    — parallel, no dependency between them
# #   3. aks               — needs VNet ID + subnet ID from step 1
# #   4. role assignments  — need AKS kubelet identity + ACR/KV IDs
# #   5. time_sleep        — gates anything reading KV after grant
# # ============================================================

# # ---- Networking ------------------------------------------------
# # Owns the resource group in dev (ADR-043: module-owned RG).
# # Produces spoke_vnet_id + aks_subnet_id consumed by AKS below.
# # enable_peering = false → standalone dev VNet, no hub peering
# # (ADR-039). The hub_* args are unused when peering is off.
# module "spoke_networking" {
#   source              = "../../modules/spoke-networking"
#   environment         = var.environment
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   spoke_cidr          = var.spoke_cidr
#   subnet_cidrs        = var.subnet_cidrs
#   common_tags         = var.common_tags
#   enable_peering      = false
#   enable_public_http_ingress = true ## plat 9.2 fix: public ingress in dev
# }

# # ---- ACR -------------------------------------------------------
# # Basic SKU — cheapest tier, sufficient for dev image storage.
# # Public network access on in dev — no private endpoint (ADR-039).
# # admin_enabled is hardcoded false inside the module (fail-closed).
# module "acr" {
#   source              = "../../modules/acr"
#   name                = var.acr_name
#   location            = var.location
#   resource_group_name = module.spoke_networking.resource_group_name
#   # resource_group_name = var.resource_group_name
#   sku                 = "Basic"
#   common_tags         = var.common_tags
# }

# # ---- Key Vault -------------------------------------------------
# # RBAC mode (enable_rbac_authorization = true in the module).
# # Public network access on in dev — no private endpoint.
# # purge_protection off so the vault can be destroyed and
# # recreated without a 90-day soft-delete wait.
# # csi_identity_object_id wires the CSI driver identity to the
# # Key Vault Secrets User role so pods can mount KV secrets
# # directly via the CSI driver (PLAT-9, ADR-029).
# module "keyvault" {
#   source              = "../../modules/keyvault"
#   name                = var.keyvault_name
#   location            = var.location
#   resource_group_name = module.spoke_networking.resource_group_name
#   # resource_group_name = var.resource_group_name
#   tenant_id           = var.tenant_id
#   sku_name            = "standard"
#   admin_object_id     = var.admin_object_id

#   public_network_access_enabled = true
#   purge_protection_enabled      = false
#   soft_delete_retention_days    = 7
#   network_acls_default_action   = "Allow"

#   # CSI driver identity — grants Key Vault Secrets User so the
#   # addon can fetch secrets at pod startup without pipeline
#   # intervention. Object ID is the CSI addon managed identity,
#   # not the kubelet identity (they are different identities).
#   csi_identity_object_id = "ee855b92-7b11-40ff-855b-91ea33e50a10"

#   common_tags = var.common_tags
# }

# # ---- AKS -------------------------------------------------------
# # Free tier — no control-plane SLA, fine for dev.
# # Public API server (private_cluster_enabled = false) so
# # Microsoft-hosted pipeline agents can reach it.
# # CNI Overlay + Cilium declared in module.
# # key_vault_secrets_provider block declared in module (PLAT-9).
# module "aks" {
#   source              = "../../modules/aks"
#   name                = var.aks_name
#   location            = var.location
#   resource_group_name = module.spoke_networking.resource_group_name
#   # resource_group_name = var.resource_group_name
#   dns_prefix          = var.aks_dns_prefix
#   kubernetes_version  = var.kubernetes_version
#   sku_tier            = "Free"

#   # Public posture — no private DNS zone needed in dev.
#   private_cluster_enabled = false
#   private_dns_zone_id     = null

#   # Networking — references spoke_networking outputs.
#   vnet_id        = module.spoke_networking.spoke_vnet_id
#   node_subnet_id = module.spoke_networking.aks_subnet_id

#   # CIDR blocks — verified from state. Must match exactly or
#   # Terraform will attempt to recreate the cluster.
#   pod_cidr       = "10.244.0.0/16"
#   service_cidr   = "172.16.0.0/16"
#   dns_service_ip = "172.16.0.10"

#   # System node pool — only_critical_addons = true taints this
#   # pool so only system pods land here. App workloads go to
#   # the workload user pool below. Verified from state.
#   default_node_pool = {
#     name                 = "system"
#     vm_size              = "Standard_D2as_v6"
#     node_count           = 1
#     auto_scaling_enabled = true
#     min_count            = 1
#     max_count            = 3
#     os_disk_size_gb      = 50
#     only_critical_addons = true
#   }

#   # User (application) node pool — Bank of Anthos pods run here.
#   # node_labels verified from state: workload=apps.
#   user_node_pools = {
#     workload = {
#       vm_size              = "Standard_D2as_v6"
#       node_count           = 1
#       auto_scaling_enabled = true
#       min_count            = 1
#       max_count            = 3
#       os_disk_size_gb      = 50
#       node_labels          = { "workload" = "apps" }
#       node_taints          = []
#       mode                 = "User"
#     }
#   }

#   # No Log Analytics in dev — saves cost (ADR-039).
#   log_analytics_workspace_id = null

#   common_tags = var.common_tags
# }

# # ---- Kubelet AcrPull -------------------------------------------
# # Grants the AKS kubelet identity pull access to ACR so pods
# # pull images without imagePullSecret. The node itself
# # authenticates to ACR using this role.
# resource "azurerm_role_assignment" "aks_kubelet_acrpull" {
#   principal_id         = module.aks.kubelet_identity_object_id
#   role_definition_name = "AcrPull"
#   scope                = module.acr.id

#   depends_on = [module.aks, module.acr]
# }

# # ---- Pipeline KV Secrets Officer -------------------------------
# # Grants the pipeline SP (sc-boa-dev) write access to KV secrets
# # so the CD pipeline can create/update secrets.
# # Secrets Officer = read + write secrets only (not keys/certs).
# resource "azurerm_role_assignment" "pipeline_kv_secrets_officer" {
#   principal_id         = var.platform_sp_object_id
#   role_definition_name = "Key Vault Secrets Officer"
#   scope                = module.keyvault.id

#   depends_on = [module.keyvault]
# }

# # ---- RBAC propagation wait -------------------------------------
# # Entra role assignments take up to 120s to propagate globally.
# # Anything that reads KV immediately after the grant above would
# # get a 403 without this wait. Verified from state: 120s.
# resource "time_sleep" "wait_for_kv_rbac" {
#   depends_on      = [azurerm_role_assignment.pipeline_kv_secrets_officer]
#   create_duration = "120s"
# }

# #---- Logging ---------------------------------------------------
# resource "azurerm_log_analytics_workspace" "dev" {
#   name                = "law-boa-dev-eus2"
#   location            = var.location
#   resource_group_name = module.spoke_networking.resource_group_name
#   sku                 = "PerGB2018"
#   retention_in_days   = 30
# }

# #---- Alert Management ---------------------------------------------------
# resource "azurerm_monitor_scheduled_query_rules_alert_v2" "boa_error_logs" {
#   name                = "boa-error-logs-dev"
#   resource_group_name = module.spoke_networking.resource_group_name
#   location            = var.location

#   description          = "Fires when BoA services log more than 10 errors in a 5-minute window"
#   evaluation_frequency = "PT5M"
#   window_duration      = "PT5M"
#   scopes               = [azurerm_log_analytics_workspace.dev.id]
#   severity             = 2
#   enabled              = true

#   criteria {
#     query = <<-QUERY
#       boa_container_logs_CL
#       | where log_s contains "ERROR" or log_s contains "Exception"
#       | where kubernetes_namespace_name_s == "boa"
#       | summarize ErrorCount = count() by bin(TimeGenerated, 5m)
#       | where ErrorCount > 10
#     QUERY

#     time_aggregation_method = "Count"
#     threshold               = 0
#     operator                = "GreaterThan"

#     failing_periods {
#       minimum_failing_periods_to_trigger_alert = 1
#       number_of_evaluation_periods             = 1
#     }
#   }

#   # No action group in dev — alert fires and is visible in Azure Monitor Alerts blade.
#   # Staging/prod: wire action_groups to an azurerm_monitor_action_group resource.
# }