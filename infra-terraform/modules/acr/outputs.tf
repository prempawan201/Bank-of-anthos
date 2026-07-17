# Registry resource ID — consumed by the AcrPull role assignment
# in the environment root so the AKS kubelet identity can pull.
output "id" {
  value = azurerm_container_registry.this.id
}

# Registry resource name.
output "name" {
  value = azurerm_container_registry.this.name
}

# FQDN used in image references and `docker login`
# (e.g. acrbankofanthos8459.azurecr.io).
output "login_server" {
  value = azurerm_container_registry.this.login_server
}