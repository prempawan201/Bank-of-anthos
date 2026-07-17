output "id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "name" {
  value = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  description = "Fully qualified domain name — resolves to private IP from within VNet"
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "administrator_login" {
  value = azurerm_postgresql_flexible_server.this.administrator_login
}

output "admin_password_kv_secret_id" {
  description = "KV secret ID for the admin password — reference in apps that need the admin cred"
  value       = azurerm_key_vault_secret.admin_password.id
}