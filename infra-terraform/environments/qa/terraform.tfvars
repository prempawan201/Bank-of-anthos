subscription_id = "cad883ef-38be-4c80-9913-4aaa7aac8d6d"
environment     = "qa"
location        = "eastus2"

common_tags = {
  environment = "qa"
  workload    = "bank-of-anthos"
  owner       = "prem"
  lifecycle   = "ephemeral"
  managed-by  = "terraform"
  cost-center = "learning"
}

spoke_cidr          = "10.20.0.0/16"
resource_group_name = "rg-boa-workload-qa-eus2"

subnet_cidrs = {
  aks_nodes         = "10.20.0.0/22"
  postgres          = "10.20.4.0/27"
  private_endpoints = "10.20.5.0/24"
  ingress           = "10.20.6.0/27"
}