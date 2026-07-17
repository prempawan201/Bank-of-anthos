terraform {
  backend "azurerm" {
    resource_group_name  = "rg-boa-bootstrap-eus2"
    storage_account_name = "stboatfstate8459"
    container_name       = "tfstate"
    key                  = "staging.tfstate"
    use_oidc             = true
  }
}