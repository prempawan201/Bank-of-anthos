# ============================================================
# environments/prod — simplified public posture
# ------------------------------------------------------------
# Hub-spoke VNet peering retained.
# AKS: public API + authorized_ip_ranges (laptop + agent VM).
# ACR: Standard, public, identity-gated. No network_rule_set.
# KV:  public, default_action=Allow, RBAC-gated. No IP filter.
# Postgres: VNet-injected — one inline private DNS zone.
# No ACR/KV PEs. No shared dns remote state. One apply.
# ADR-048: PE-drop decision recorded.
# ============================================================

# ── Remote state: hub only ───────────────────────────────────
# No dns remote state — no shared zones in prod.
data "terraform_remote_state" "hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-boa-bootstrap-eus2"
    storage_account_name = "stboatfstate8459"
    container_name       = "tfstate"
    key                  = "hub.tfstate"
    # use_oidc             = true
  }
}

# ── Spoke networking (peered to hub) ─────────────────────────
module "spoke_networking" {
  source = "../../modules/spoke-networking"

  environment             = var.environment
  location                = var.location
  common_tags             = var.common_tags
  spoke_cidr              = var.spoke_cidr
  subnet_cidrs            = var.subnet_cidrs
  resource_group_name     = var.resource_group_name
  enable_peering          = true
  hub_vnet_id             = data.terraform_remote_state.hub.outputs.hub_vnet_id
  hub_vnet_name           = data.terraform_remote_state.hub.outputs.hub_vnet_name
  hub_resource_group_name = data.terraform_remote_state.hub.outputs.hub_resource_group_name
}

# ── ACR — Standard, public, identity-gated ───────────────────
# Standard SKU: network_rule_set not supported.
# Protection = AcrPull (kubelet MI) + AcrPush (CI SC). Auth-only.
# Dropped vs staging: acr-private-endpoint module, privatelink.azurecr.io zone.
module "acr" {
  source = "../../modules/acr"

  name                          = var.acr_name
  resource_group_name           = module.spoke_networking.resource_group_name
  location                      = var.location
  common_tags                   = var.common_tags
  sku                           = "Standard"
  public_network_access_enabled = true
  log_analytics_workspace_id    = data.terraform_remote_state.hub.outputs.log_analytics_workspace_id
}

# AcrPull: kubelet identity pulls from prod ACR
resource "azurerm_role_assignment" "aks_kubelet_acrpull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity_object_id
}

# # AcrPush: prod CI service connection (sc-boa-acr-prod). GATE E.
# resource "azurerm_role_assignment" "prod_ci_acrpush" {
#   scope                = module.acr.id
#   role_definition_name = "AcrPush"
#   principal_id         = var.prod_ci_sp_object_id
# }

# AcrPush: prod CI service connection (sc-boa-acr-prod). GATE E.
# count gate: SC doesn't exist until ACR is applied (chicken-and-egg).
# Empty object_id on first apply → 0 resources; fill after SC created → 1.
resource "azurerm_role_assignment" "prod_ci_acrpush" {
  count                = var.prod_ci_sp_object_id != "" ? 1 : 0
  scope                = module.acr.id
  role_definition_name = "AcrPush"
  principal_id         = var.prod_ci_sp_object_id
}

# ── Key Vault — public, RBAC-gated ───────────────────────────
# public_network_access_enabled = true, default_action = Allow.
# No IP filter → no NAT Gateway needed.
# Dropped vs staging: keyvault-private-endpoint module, privatelink.vaultcore.azure.net zone.
module "keyvault" {
  source = "../../modules/keyvault"

  name                          = var.keyvault_name
  resource_group_name           = module.spoke_networking.resource_group_name
  location                      = var.location
  common_tags                   = var.common_tags
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
  admin_object_id               = var.admin_object_id
  public_network_access_enabled = true
  network_acls_default_action   = "Allow"
  log_analytics_workspace_id    = data.terraform_remote_state.hub.outputs.log_analytics_workspace_id
}

# KV RBAC grants
resource "azurerm_role_assignment" "pipeline_kv_secrets_officer" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.platform_sp_object_id
}

resource "azurerm_role_assignment" "agent_kv_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.terraform_remote_state.hub.outputs.agent_principal_id
}

resource "time_sleep" "wait_for_kv_rbac" {
  depends_on = [
    azurerm_role_assignment.pipeline_kv_secrets_officer,
    azurerm_role_assignment.agent_kv_secrets_user,
  ]
  create_duration = "120s"
}

# ── AKS — public API, IP-restricted ──────────────────────────
# private_cluster_enabled = false → no azmk8s.io zone.
# private_dns_zone_id = null → module skips private zone wiring.
# authorized_ip_ranges = laptop + agent VM (GATE C).
# Agent VM IP is load-bearing for Helm CD — wrong IP = CD broken.
module "aks" {
  source = "../../modules/aks"

  name                = var.aks_name
  resource_group_name = module.spoke_networking.resource_group_name
  location            = var.location
  common_tags         = var.common_tags

  dns_prefix         = var.aks_dns_prefix
  kubernetes_version = var.kubernetes_version

  node_subnet_id = module.spoke_networking.aks_subnet_id
  vnet_id        = module.spoke_networking.spoke_vnet_id

  private_cluster_enabled    = false
  private_dns_zone_id        = null
  authorized_ip_ranges       = var.aks_authorized_ip_ranges
  sku_tier                   = var.aks_sku_tier
  log_analytics_workspace_id = data.terraform_remote_state.hub.outputs.log_analytics_workspace_id

  user_node_pools = var.user_node_pools
}

# # AcrPull depends on AKS — kubelet identity doesn't exist until cluster is created
# resource "azurerm_role_assignment" "aks_kubelet_acrpull" {
#   scope                = module.acr.id
#   role_definition_name = "AcrPull"
#   principal_id         = module.aks.kubelet_identity_object_id
# }

# ── Postgres private DNS zone — INLINE ───────────────────────
# The one zone Azure forces for VNet-injected flexible server.
# Inline (not shared dns env) → single apply, no re-link dance.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = module.spoke_networking.resource_group_name
  tags                = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres_spoke" {
  name                  = "boa-prod-pg-link"
  resource_group_name   = module.spoke_networking.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = module.spoke_networking.spoke_vnet_id
  registration_enabled  = false
  tags                  = var.common_tags
}

# ── Postgres — VNet-injected, private data tier ──────────────
# Identical shape to staging. private_dns_zone_id → inline zone above,
# not dns remote state.
module "postgres" {
  source = "../../modules/postgres"

  name                         = var.postgres_name
  resource_group_name          = module.spoke_networking.resource_group_name
  location                     = var.location
  common_tags                  = var.common_tags
  administrator_login          = var.postgres_admin_login
  sku_name                     = var.postgres_sku
  backup_retention_days        = var.postgres_backup_retention_days
  geo_redundant_backup_enabled = var.postgres_geo_redundant_backup
  delegated_subnet_id          = module.spoke_networking.postgres_subnet_id
  private_dns_zone_id          = azurerm_private_dns_zone.postgres.id
  key_vault_id                 = module.keyvault.id
  tenant_id                    = var.tenant_id
  log_analytics_workspace_id   = data.terraform_remote_state.hub.outputs.log_analytics_workspace_id

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres_spoke,
    time_sleep.wait_for_kv_rbac,
  ]
}

# ── Postgres AD admin = prod SP ──────────────────────────────
# Standalone resource — NOT a module input (confirmed from staging).
# GATE A: object_id and principal_name must be the SAME SP.
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "this" {
  server_name         = module.postgres.name
  resource_group_name = module.spoke_networking.resource_group_name
  tenant_id           = var.tenant_id
  object_id           = var.platform_sp_object_id
  principal_name      = var.prod_sp_display_name
  principal_type      = "ServicePrincipal"

  lifecycle {
    ignore_changes = [principal_name]
  }
}

# ── JWT signing keypair ──────────────────────────────────────
# Same KV secret names as staging → Helm chart + SecretProviderClass
# need zero per-env changes.
resource "tls_private_key" "jwt" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "jwt_private" {
  name         = "jwt-private-key"
  value        = tls_private_key.jwt.private_key_pem
  key_vault_id = module.keyvault.id
  depends_on   = [time_sleep.wait_for_kv_rbac]
}

resource "azurerm_key_vault_secret" "jwt_public" {
  name         = "jwt-public-key"
  value        = tls_private_key.jwt.public_key_pem
  key_vault_id = module.keyvault.id
  depends_on   = [time_sleep.wait_for_kv_rbac]
}

# ── CSI driver → KV read access ─────────────────────────────
resource "azurerm_role_assignment" "csi_kv_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.aks.key_vault_secrets_provider_object_id
}