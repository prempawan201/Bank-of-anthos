# Private endpoint resource ID.
output "id" {
  value = azurerm_private_endpoint.acr.id
}

# The private IP assigned to the endpoint's NIC — useful for
# debugging DNS resolution and confirming the PE landed in the
# expected subnet range.
output "private_ip" {
  value = azurerm_private_endpoint.acr.private_service_connection[0].private_ip_address
}