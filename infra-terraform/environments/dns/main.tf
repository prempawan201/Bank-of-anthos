# ============================================================
# environments/dns — shared private DNS zones (persistent)
# ------------------------------------------------------------
# The resolution half of "going private". Creates the privatelink
# zones (KV, ACR, Postgres, Blob, AKS) and links them to the VNets
# that actually use private endpoints.
#
# Persistent shared env, like hub. Read by staging/prod (their
# private-endpoint modules look up zone IDs here via remote state).
#
# Links ONLY to hub and PRIVATE spokes (staging, prod). Dev is
# excluded: it's public (no private endpoints to resolve) and
# ephemeral (destroyed nightly) — linking it would create useless
# links AND couple this persistent env to a state that disappears.
# ============================================================

# Hub VNet — always linked (shared services resolve private endpoints).
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

# Private spokes — uncomment each AFTER that env's spoke VNet is
# applied, then re-apply dns to add its link (resolves the
# spoke/dns chicken-and-egg incrementally).
#
data "terraform_remote_state" "staging" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-boa-bootstrap-eus2"
    storage_account_name = "stboatfstate8459"
    container_name       = "tfstate"
    key                  = "staging.tfstate"
    use_oidc             = true
  }
}

# data "terraform_remote_state" "prod" {
#   backend = "azurerm"
#   config = {
#     resource_group_name  = "rg-boa-bootstrap-eus2"
#     storage_account_name = "stboatfstate8459"
#     container_name       = "tfstate"
#     key                  = "prod.tfstate"
#     use_oidc             = true
#   }
# }

module "private_dns" {
  source = "../../modules/private-dns"

  location    = var.location
  common_tags = var.common_tags

  # The module's filter links the AKS zone to "hub" only; every
  # other zone links to all VNets listed here. Add private spokes
  # as they come online.
  vnet_links = {
    hub = data.terraform_remote_state.hub.outputs.hub_vnet_id
    staging = data.terraform_remote_state.staging.outputs.spoke_vnet_id
    # prod    = data.terraform_remote_state.prod.outputs.spoke_vnet_id
  }
}