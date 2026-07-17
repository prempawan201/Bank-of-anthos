# Vault resource ID — scope for secret role assignments and the
# value consumers read via remote state (e.g. postgres key_vault_id).
output "id" {
  value = azurerm_key_vault.this.id
}

# Vault name.
output "name" {
  value = azurerm_key_vault.this.name
}

# Vault data-plane URI (https://<name>.vault.azure.net/) — used by
# apps and the agent VM's PAT fetch.
output "uri" {
  value = azurerm_key_vault.this.vault_uri
}