subscription_id = "cad883ef-38be-4c80-9913-4aaa7aac8d6d"
tenant_id       = "3d61c161-b515-4531-8ac0-34bfcdf6be81"
environment     = "dev"
location        = "eastus2"

resource_group_name = "rg-boa-workload-dev-eus2"

common_tags = {
  environment = "dev"
  workload    = "bank-of-anthos"
  owner       = "prem"
  lifecycle   = "ephemeral"
  managed-by  = "terraform"
  cost-center = "learning"
}

spoke_cidr = "10.10.0.0/16"
subnet_cidrs = {
  aks_nodes         = "10.10.0.0/22"
  postgres          = "10.10.4.0/27"
  private_endpoints = "10.10.5.0/24"
  ingress           = "10.10.6.0/27"
}

acr_name      = "acrbankofanthos8459" # ⚠ must not collide with the old rg-boa-acr-eus2 ACR — confirm that's deleted
keyvault_name = "kv-boa-dev-8459"

admin_object_id       = "f90141cc-e50b-4102-8053-39d4f7137a93"
platform_sp_object_id = "b305fd07-6943-4b41-99ba-85f90ae9f96b"

aks_name           = "aks-boa-dev-eus2"
aks_dns_prefix     = "boa-dev"
kubernetes_version = "1.33.12"