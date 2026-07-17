# ============================================================
# backend.tf
# ------------------------------------------------------------
# Remote state in the shared bootstrap storage account. Each env
# uses a distinct key so states never collide. OIDC auth.
# Per-env key:
#   hub      → hub.tfstate
#   dns      → dns.tfstate
#   dev      → dev.tfstate
#   staging  → staging.tfstate
#   prod     → prod.tfstate
# ============================================================
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-boa-bootstrap-eus2"
    storage_account_name = "stboatfstate8459"
    container_name       = "tfstate"
    key                  = "dns.tfstate" # ← change per env
    use_oidc             =  true 
  }
}