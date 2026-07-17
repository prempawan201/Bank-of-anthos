subscription_id = "cad883ef-38be-4c80-9913-4aaa7aac8d6d"
tenant_id       = "3d61c161-b515-4531-8ac0-34bfcdf6be81"
environment     = "staging"
location        = "eastus2"

resource_group_name = "rg-boa-workload-staging-eus2"

common_tags = {
  environment = "staging"
  workload    = "bank-of-anthos"
  owner       = "prem"
  lifecycle   = "persistent"
  managed-by  = "terraform"
  cost-center = "learning"
}

spoke_cidr = "10.20.0.0/16"
subnet_cidrs = {
  aks_nodes         = "10.20.0.0/22"
  postgres          = "10.20.4.0/27"
  private_endpoints = "10.20.5.0/24"
  ingress           = "10.20.6.0/27"
}

acr_name      = "acrboastaging8459"   # globally unique — adjust if taken
keyvault_name = "kv-boa-staging-8459"

admin_object_id       = "f90141cc-e50b-4102-8053-39d4f7137a93"
platform_sp_object_id = "cb9957c6-ac09-4309-8126-33dabb79e648"

aks_name           = "aks-boa-staging-eus2"
aks_dns_prefix     = "boa-staging"
kubernetes_version = "1.33.11"

postgres_name        = "psql-boa-staging-8459"
postgres_admin_login = "pgadmin"
postgres_sku         = "B_Standard_B1ms"