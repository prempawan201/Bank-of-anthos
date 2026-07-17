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

module "spoke_networking" {
  source = "../../modules/spoke-networking"

  environment             = var.environment
  location                = var.location
  common_tags             = var.common_tags
  spoke_cidr              = var.spoke_cidr
  subnet_cidrs            = var.subnet_cidrs
  resource_group_name     = var.resource_group_name
  hub_vnet_id             = data.terraform_remote_state.hub.outputs.hub_vnet_id
  hub_vnet_name           = data.terraform_remote_state.hub.outputs.hub_vnet_name
  hub_resource_group_name = data.terraform_remote_state.hub.outputs.hub_resource_group_name
}

output "spoke_vnet_id" { value = module.spoke_networking.spoke_vnet_id }
output "aks_subnet_id" { value = module.spoke_networking.aks_subnet_id }
output "postgres_subnet_id" { value = module.spoke_networking.postgres_subnet_id }
output "private_endpoints_subnet_id" { value = module.spoke_networking.private_endpoints_subnet_id }
output "ingress_subnet_id" { value = module.spoke_networking.ingress_subnet_id }