subscription_id = "cad883ef-38be-4c80-9913-4aaa7aac8d6d"
location        = "eastus2"
hub_cidr        = "10.0.0.0/16"
your_home_ip    = "171.79.56.242/32" # curl ifconfig.me

common_tags = {
  workload    = "bank-of-anthos"
  owner       = "prem"
  lifecycle   = "persistent"
  managed-by  = "terraform"
  cost-center = "learning"
}

log_analytics_name = "log-boa-platform-eus2"

agent_vm_name  = "vm-boa-agent-01"
agent_vm_size  = "Standard_D2s_v3" # B2s is cheaper if you want to trim idle cost
azdo_org_url   = "https://dev.azure.com/kprempawan1"
azdo_pool_name = "boa-self-hosted"

agent_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEJHIpRcM5X3c0gz3RZJmGscAmnYnXChah9+Uoq/bjVP prem_201@PPK"

# reverted to PAT delivery via TF_VAR_azdo_pat secret var and cloud-init customData; see variables.tf for rationale.
# azdo_pat = "azure-devops-pat-goes-here" # NEVER set this in code or tfvars; pipeline secret var → TF_VAR_azdo_pat
# failed experiment: Managed Identity approach, proved more complex and required more AZURE RBAC permissions (UAMI pre-registration, plus Secrets User on staging KV for deploy-time reads) than the simple PAT + customData approach. Reverting to PAT delivery via TF_VAR_azdo_pat secret var and cloud-init customData; see variables.tf for rationale. The hub remains self-contained with no Key Vault and no secrets read at runtime; the PAT is only used for ADO registration at provisioning time, delivered securely via pipeline secrets and cloud-init.