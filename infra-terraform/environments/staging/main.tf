# ============================================================
# environments/staging — production-grade PRIVATE environment
# ------------------------------------------------------------
# Full private topology, mirrors prod (smaller scale):
#   - spoke VNet peered to hub (10.20.0.0/16)
#   - own Premium ACR + private endpoint
#   - private Key Vault + private endpoint
#   - private AKS cluster
#   - Postgres Flexible Server (VNet-integrated)
#   - Workload Identity for app services
#
# Reads hub (VNet, Log Analytics, agent identity) and dns (zone
# IDs) via remote state. Long-lived — not destroyed nightly.
#
# Apply prerequisites: hub and dns must be applied first. After
# this env's spoke VNet exists, re-apply dns to add staging's
# VNet link (the spoke/dns chicken-and-egg).
# ============================================================

# ── Remote state: hub ────────────────────────────────────────
data "terraform_remote_state" "hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-boa-bootstrap-eus2"
    storage_account_name = "stboatfstate8459"
    container_name       = "tfstate"
    key                  = "hub.tfstate"
    use_oidc             = true
  }
}

# ── Remote state: dns (private zone IDs) ─────────────────────
data "terraform_remote_state" "dns" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-boa-bootstrap-eus2"
    storage_account_name = "stboatfstate8459"
    container_name       = "tfstate"
    key                  = "dns.tfstate"
    use_oidc             = true
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

# ── ACR (Premium, private — built inline) ────────────────────
module "acr" {
  source = "../../modules/acr"

  name                          = var.acr_name
  resource_group_name           = module.spoke_networking.resource_group_name
  location                      = var.location
  common_tags                   = var.common_tags
  sku                           = "Premium"
  public_network_access_enabled = false
  log_analytics_workspace_id    = data.terraform_remote_state.hub.outputs.log_analytics_workspace_id
}

module "acr_private_endpoint" {
  source = "../../modules/acr-private-endpoint"

  name                = "pe-acr-${var.environment}"
  resource_group_name = module.spoke_networking.resource_group_name
  location            = var.location
  common_tags         = var.common_tags
  subnet_id           = module.spoke_networking.private_endpoints_subnet_id
  acr_id              = module.acr.id
  private_dns_zone_id = data.terraform_remote_state.dns.outputs.zone_ids["privatelink.azurecr.io"]
}

# ── Key Vault (private) + private endpoint ───────────────────
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
  public_network_access_enabled = false
  network_acls_default_action   = "Deny"
  log_analytics_workspace_id    = data.terraform_remote_state.hub.outputs.log_analytics_workspace_id
}

module "keyvault_private_endpoint" {
  source = "../../modules/keyvault-private-endpoint"

  name                = "pe-kv-${var.environment}"
  resource_group_name = module.spoke_networking.resource_group_name
  location            = var.location
  common_tags         = var.common_tags
  subnet_id           = module.spoke_networking.private_endpoints_subnet_id
  keyvault_id         = module.keyvault.id
  private_dns_zone_id = data.terraform_remote_state.dns.outputs.zone_ids["privatelink.vaultcore.azure.net"]
}

# ── KV access grants ─────────────────────────────────────────
# Pipeline SP — writes the Postgres admin password (getSecret +
# setSecret → Secrets Officer).
resource "azurerm_role_assignment" "pipeline_kv_secrets_officer" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.platform_sp_object_id
}

# Hub agent identity — reads secrets during deployment work.
# CORRECTION: reads hub's agent_principal_id via remote state
# (was a hardcoded principal in the old template). Works for both
# PAT and managed_identity agent modes since hub outputs the right
# principal either way.
resource "azurerm_role_assignment" "agent_kv_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.terraform_remote_state.hub.outputs.agent_principal_id
}

# Absorb RBAC propagation before the postgres module writes secrets.
resource "time_sleep" "wait_for_kv_rbac" {
  depends_on = [
    azurerm_role_assignment.pipeline_kv_secrets_officer,
    azurerm_role_assignment.agent_kv_secrets_user,
  ]
  create_duration = "120s"
}

# ── AKS (private cluster, Standard tier) ─────────────────────
module "aks" {
  source = "../../modules/aks"

  name                = var.aks_name
  resource_group_name = module.spoke_networking.resource_group_name
  location            = var.location
  common_tags         = var.common_tags

  dns_prefix         = var.aks_dns_prefix
  kubernetes_version = var.kubernetes_version

  node_subnet_id      = module.spoke_networking.aks_subnet_id
  vnet_id             = module.spoke_networking.spoke_vnet_id
  private_dns_zone_id = data.terraform_remote_state.dns.outputs.zone_ids["privatelink.eastus2.azmk8s.io"]

  log_analytics_workspace_id = data.terraform_remote_state.hub.outputs.log_analytics_workspace_id

  private_cluster_enabled = true
  sku_tier                = "Standard"

  user_node_pools = {
    workload = {
      vm_size              = "Standard_D2as_v6"
      node_count           = 2
      min_count            = 1
      max_count            = 4
      auto_scaling_enabled = true
      os_disk_size_gb      = 50
      node_labels          = { workload = "apps" }
      node_taints          = []
      mode                 = "User"
    }
  }
}

# ── AcrPull: kubelet pulls from the inline ACR ───────────────
resource "azurerm_role_assignment" "aks_kubelet_acrpull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity_object_id
}

# ── Postgres (VNet-integrated, private) ──────────────────────
module "postgres" {
  source = "../../modules/postgres"

  name                       = var.postgres_name
  resource_group_name        = module.spoke_networking.resource_group_name
  location                   = var.location
  common_tags                = var.common_tags
  administrator_login        = var.postgres_admin_login
  sku_name                   = var.postgres_sku
  delegated_subnet_id        = module.spoke_networking.postgres_subnet_id
  private_dns_zone_id        = data.terraform_remote_state.dns.outputs.zone_ids["privatelink.postgres.database.azure.com"]
  key_vault_id               = module.keyvault.id
  tenant_id                  = var.tenant_id
  log_analytics_workspace_id = data.terraform_remote_state.hub.outputs.log_analytics_workspace_id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

# Postgres AD admin = the platform SP.
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "this" {
  server_name         = module.postgres.name
  resource_group_name = module.spoke_networking.resource_group_name
  tenant_id           = var.tenant_id
  object_id           = var.platform_sp_object_id
  principal_name      = "kprempawan1-bank-of-anthos-platform-16037398-d063-48e7-a66a-4afe1e5b8414"
  principal_type      = "ServicePrincipal"

  lifecycle {
    ignore_changes = [principal_name] # AD admin name is immutable; ignore drift
  }
}


# AcrPush for the staging CI service connection (sc-boa-acr-staging).
# WIF-backed Docker Registry SC — push only, no ARM rights.
# ADO auto-creates this grant on SC creation; imported into state
# rather than letting Terraform create it.
resource "azurerm_role_assignment" "staging_ci_acrpush" {
  scope                = module.acr.id
  role_definition_name = "AcrPush"
  principal_id         = "6b960487-f506-4d5d-ace8-6dcfe8896d8b"
}


# # ── Workload Identity for app services ───────────────────────
# module "accounts_svc_wi" {
#   source                   = "../../modules/workload-identity"
#   app_name                 = "boa-accounts-svc-${var.environment}"
#   k8s_namespace            = "bank-of-anthos"
#   k8s_service_account_name = "accounts-svc"
#   aks_oidc_issuer_url      = module.aks.oidc_issuer_url
# }

# resource "azurerm_role_assignment" "accounts_svc_kv" {
#   scope                = module.keyvault.id
#   role_definition_name = "Key Vault Secrets User"
#   principal_id         = module.accounts_svc_wi.service_principal_object_id
# }

# module "ledger_svc_wi" {
#   source                   = "../../modules/workload-identity"
#   app_name                 = "boa-ledger-svc-${var.environment}"
#   k8s_namespace            = "bank-of-anthos"
#   k8s_service_account_name = "ledger-svc"
#   aks_oidc_issuer_url      = module.aks.oidc_issuer_url
# }

# resource "azurerm_role_assignment" "ledger_svc_kv" {
#   scope                = module.keyvault.id
#   role_definition_name = "Key Vault Secrets User"
#   principal_id         = module.ledger_svc_wi.service_principal_object_id
# }

# ── JWT signing keypair (tracked) ────────────────────────────
# Replaces dev's manual openssl + `az keyvault secret set`. Terraform
# generates the RSA-4096 pair and lands both halves into the private
# staging KV via the pipeline SP's existing Secrets Officer grant.
# Names match dev EXACTLY (jwt-private-key / jwt-public-key) so the
# Helm chart + SecretProviderClass need zero per-env renaming.
resource "tls_private_key" "jwt" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "jwt_private" {
  name         = "jwt-private-key"
  value        = tls_private_key.jwt.private_key_pem
  key_vault_id = module.keyvault.id
  depends_on   = [time_sleep.wait_for_kv_rbac] # Secrets Officer grant propagated
}

resource "azurerm_key_vault_secret" "jwt_public" {
  name         = "jwt-public-key"
  value        = tls_private_key.jwt.public_key_pem
  key_vault_id = module.keyvault.id
  depends_on   = [time_sleep.wait_for_kv_rbac]
}

# ── CSI driver → KV read access ──────────────────────────────
# Lets the Secrets Store CSI addon mount jwt-private-key / jwt-public-key
# into pods at runtime. AKS dependency is implicit via the principal_id
# reference — Terraform orders this after the cluster automatically.
# Single apply; no second pass.
resource "azurerm_role_assignment" "csi_kv_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.aks.key_vault_secrets_provider_object_id
} 