# ============================================================
# versions.tf — Terraform core + provider locks (all envs)
# ------------------------------------------------------------
#   azurerm ~> 4.0  : all Azure resources (latest 4.75.x)
#   azuread ~> 3.0  : workload-identity app/SP/federated creds
#                     (staging/prod; harmless where unused)
#   random  ~> 3.6  : random_password (postgres)
#   time    ~> 0.11 : time_sleep (RBAC propagation waits)
# required_version >= 1.9.0: keep the actual binary consistent
#   with the version that wrote state.
# ============================================================
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}