subscription_id = "cad883ef-38be-4c80-9913-4aaa7aac8d6d"
tenant_id       = "3d61c161-b515-4531-8ac0-34bfcdf6be81"

environment = "prod"
location    = "eastus2"

common_tags = {
  environment = "prod"
  project     = "bank-of-anthos"
  managed_by  = "terraform"
}

# ── Networking ───────────────────────────────────────────────
resource_group_name = "rg-boa-workload-prod-eus2"
spoke_cidr          = "10.30.0.0/16"

subnet_cidrs = {
  aks_nodes         = "10.30.1.0/24"
  postgres          = "10.30.2.0/24"
  private_endpoints = "10.30.3.0/24"  # module requires this key; no PEs in prod
  ingress           = "10.30.4.0/24"
}

# ── ACR ──────────────────────────────────────────────────────
acr_name = "acrboaprod8459"

# ── Key Vault ────────────────────────────────────────────────
keyvault_name   = "kv-boa-prod-8459"
admin_object_id = "FILL_GATE_A"   # prod SP object ID

# ── AKS ──────────────────────────────────────────────────────
aks_name       = "aks-boa-prod-eus2"
aks_dns_prefix = "aks-boa-prod"

# Run: az aks show -g rg-boa-workload-staging-eus2 -n aks-boa-staging-eus2 --query kubernetesVersion -o tsv
kubernetes_version = "FILL_FROM_STAGING"

# GATE C: replace with real IPs before plan
aks_authorized_ip_ranges = ["LAPTOP_IP/32", "AGENT_VM_IP/32"]
aks_sku_tier             = "Free"

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

# ── Postgres ─────────────────────────────────────────────────
postgres_name                  = "psql-boa-prod-8459"
postgres_admin_login           = "pgadmin"
postgres_sku                   = "B_Standard_B1ms"
postgres_backup_retention_days = 7
postgres_geo_redundant_backup  = false

# ── Identity (fill after GATE A + GATE E) ────────────────────
platform_sp_object_id = "f4332767-8304-45d5-819f-54f30127c340"
# admin_object_id       = "f4332767-8304-45d5-819f-54f30127c340"
prod_sp_display_name  = "kprempawan1-bank-of-anthos-platform-5e3e3245-4b6e-4096-b653-41b8894532f5"