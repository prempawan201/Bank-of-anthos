variable "resource_group_name" {
  description = "RG holding the private DNS zones — persistent, shared across environments"
  type        = string
  default     = "rg-boa-dns-eus2"
}

variable "location" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "vnet_links" {
  description = <<-EOT
    Map of VNet label → VNet ID. Each zone is linked to each VNet here,
    EXCEPT the AKS zone (privatelink.eastus2.azmk8s.io), which is linked
    only to the "hub" label — AKS creates its own link to each spoke.
    Example: { hub = "<hub-vnet-id>", staging = "<spoke-vnet-id>" }
  EOT
  type        = map(string)
}