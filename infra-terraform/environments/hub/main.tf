# ============================================================
# environments/hub — shared persistent infrastructure
# ------------------------------------------------------------
# The hub of the hub-and-spoke. Persistent — never destroyed with
# ephemeral workload envs. Provides:
#   - hub VNet + subnets (spokes peer into this)
#   - central Log Analytics (staging/prod ship diagnostics here)
#   - the self-hosted agent VM that deploys PRIVATE staging/prod
#     environments a hosted agent can't reach
#
# Consumed by staging/prod via remote state. Dev does NOT use the
# hub (dev is a standalone public VNet).
#
# Agent auth: PAT (ADR-012). The registration PAT is delivered via
# cloud-init customData as a SECURE pipeline variable (TF_VAR_azdo_pat)
# from tf-platform — NOT from any Key Vault. There is no hub KV, and
# reading the staging KV would invert the hub→spoke dependency. Hub
# stores/reads no secret for registration and stays self-contained.
#
# The VM keeps a system-assigned identity for AZURE RBAC: staging
# grants agent_principal_id Secrets User on the STAGING KV for
# deploy-time secret reads. PAT governs ADO registration only.
# ============================================================

module "hub_networking" {
  source = "../../modules/hub-networking"

  location     = var.location
  common_tags  = var.common_tags
  hub_cidr     = var.hub_cidr
  your_home_ip = var.your_home_ip
}

output "hub_vnet_id" { value = module.hub_networking.hub_vnet_id }
output "hub_vnet_name" { value = module.hub_networking.hub_vnet_name }
output "hub_resource_group_name" { value = module.hub_networking.hub_resource_group_name }
output "agent_subnet_id" { value = module.hub_networking.agent_subnet_id }

# Central log sink. staging/prod modules pass this workspace ID to
# wire their diagnostics/Container Insights. Dev passes null and
# skips diagnostics entirely (cost saving).
module "log_analytics" {
  source = "../../modules/log-analytics"

  name                = var.log_analytics_name
  resource_group_name = module.hub_networking.hub_resource_group_name
  location            = var.location
  common_tags         = var.common_tags
  retention_in_days   = 30
}

output "log_analytics_workspace_id" { value = module.log_analytics.id }

# Self-hosted agent VM, PAT mode (customData delivery, no KV).
# - System-assigned identity (no UAMI pre-registration needed).
# - PAT arrives via cloud-init customData from TF_VAR_azdo_pat.
# - principal_id: staging/prod grant this Secrets User on their own
#   KV for deployment-time secret reads (downward, correct).
module "agent_vm" {
  source = "../../modules/agent-vm"

  name                = var.agent_vm_name
  resource_group_name = module.hub_networking.hub_resource_group_name
  location            = var.location
  common_tags         = var.common_tags
  subnet_id           = module.hub_networking.agent_subnet_id
  ssh_public_key      = var.agent_ssh_public_key
  azdo_org_url        = var.azdo_org_url
  azdo_pool_name      = var.azdo_pool_name
  vm_size             = var.agent_vm_size

  agent_auth_mode = "pat"
  azdo_pat        = var.azdo_pat # sensitive; TF_VAR_azdo_pat secret var → customData
}

output "agent_vm_id" { value = module.agent_vm.vm_id }
output "agent_vm_private_ip" { value = module.agent_vm.private_ip }

# The agent identity principal — staging/prod read this via remote
# state and grant it Secrets User on their KV for deployment work.
output "agent_principal_id" { value = module.agent_vm.principal_id }

# ---- Azure Bastion ----------------------------------------------------------
# Re-surface the module's Bastion IP at the env level so it shows in
# `terraform output`. Reads the module output declared in hub-networking.
# Bastion deploys fine without this — it's purely for visibility.
# output "bastion_public_ip" { value = module.hub_networking.bastion_public_ip }