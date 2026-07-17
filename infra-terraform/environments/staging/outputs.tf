output "spoke_vnet_id" { value = module.spoke_networking.spoke_vnet_id }
output "aks_subnet_id" { value = module.spoke_networking.aks_subnet_id }
output "private_endpoints_subnet_id" { value = module.spoke_networking.private_endpoints_subnet_id }

output "acr_id" { value = module.acr.id }
output "acr_login_server" { value = module.acr.login_server }

output "keyvault_id" { value = module.keyvault.id }
output "keyvault_uri" { value = module.keyvault.uri }

output "aks_id" { value = module.aks.id }
output "aks_name" { value = module.aks.name }
output "aks_oidc_issuer_url" { value = module.aks.oidc_issuer_url }
output "aks_private_fqdn" { value = module.aks.private_fqdn }
output "aks_node_resource_group" { value = module.aks.node_resource_group }

output "postgres_fqdn" { value = module.postgres.fqdn }
output "postgres_name" { value = module.postgres.name }

# output "accounts_svc_client_id" { value = module.accounts_svc_wi.client_id }
# output "ledger_svc_client_id" { value = module.ledger_svc_wi.client_id }