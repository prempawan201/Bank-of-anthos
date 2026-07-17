output "spoke_vnet_id"               { value = module.spoke_networking.spoke_vnet_id }
output "aks_subnet_id"               { value = module.spoke_networking.aks_subnet_id }
output "resource_group_name"         { value = module.spoke_networking.resource_group_name }

output "acr_id"                      { value = module.acr.id }
output "acr_login_server"            { value = module.acr.login_server }

output "keyvault_id"                 { value = module.keyvault.id }
output "keyvault_uri"                { value = module.keyvault.uri }

output "aks_id"                      { value = module.aks.id }
output "aks_name"                    { value = module.aks.name }
output "aks_oidc_issuer_url"         { value = module.aks.oidc_issuer_url }
output "aks_node_resource_group"     { value = module.aks.node_resource_group }

output "postgres_fqdn"               { value = module.postgres.fqdn }
output "postgres_name"               { value = module.postgres.name }