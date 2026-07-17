# Private endpoint resource ID.
output "id" {
  value = azurerm_private_endpoint.kv.id
}

# Private IP assigned to the endpoint's NIC — useful for verifying
# DNS resolution returns the private address and the PE landed in
# the expected subnet range.
output "private_ip" {
  value = azurerm_private_endpoint.kv.private_service_connection[0].private_ip_address
}