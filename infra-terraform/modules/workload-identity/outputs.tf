# Client ID — goes on the K8s ServiceAccount as the
# azure.workload.identity/client-id annotation so pods using that
# SA pick up this identity.
output "client_id" {
  description = "Client ID — annotate the ServiceAccount with this"
  value       = azuread_application.this.client_id
}

# SP object ID — the principal for Azure RBAC role assignments
# (e.g. granting this identity Key Vault Secrets User).
output "service_principal_object_id" {
  description = "SP object ID — use for Azure role assignments"
  value       = azuread_service_principal.this.object_id
}

# Convenience: the full annotation line to drop onto the SA manifest.
output "annotation_value" {
  description = "Convenience: the full annotation value for the SA"
  value       = "azure.workload.identity/client-id: ${azuread_application.this.client_id}"
}