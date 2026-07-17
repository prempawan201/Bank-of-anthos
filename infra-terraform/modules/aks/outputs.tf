# Cluster resource ID.
output "id" {
  value = azurerm_kubernetes_cluster.this.id
}

# Cluster name.
output "name" {
  value = azurerm_kubernetes_cluster.this.name
}

# Auto-created kubelet identity object ID. The environment root
# grants this AcrPull on the registry so nodes can pull images.
output "kubelet_identity_object_id" {
  description = "Object ID of the auto-created kubelet identity — for AcrPull role assignment"
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

# OIDC issuer URL — the trust anchor for Workload Identity
# federated credentials (KV access from pods without secrets).
output "oidc_issuer_url" {
  description = "OIDC issuer URL — needed for Workload Identity federated credentials"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

# Private API server FQDN. Populated only for a private cluster;
# empty/null for a public dev cluster.
output "private_fqdn" {
  value = azurerm_kubernetes_cluster.this.private_fqdn
}

# The auto-managed MC_* resource group holding node infrastructure.
output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

# CSI Secrets Store addon identity object ID. The environment root
# grants this Key Vault Secrets User so pods can mount KV secrets
# (e.g. the JWT signing keys) via the SecretProviderClass at runtime.
output "key_vault_secrets_provider_object_id" {
  description = "Object ID of the AKS Key Vault Secrets Provider (CSI) addon identity — for KV Secrets User role assignment"
  value       = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
}