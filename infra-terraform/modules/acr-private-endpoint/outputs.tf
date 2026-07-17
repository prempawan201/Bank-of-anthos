variable "name" {
  description = "Private endpoint name (e.g. pe-acr-staging)"
  type        = string
}

variable "resource_group_name" {
  description = "RG the private endpoint is created in — the environment's spoke/workload RG"
  type        = string
}

variable "location" {
  description = "Azure region — must match the spoke VNet's region"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to the private endpoint"
  type        = map(string)
}

variable "subnet_id" {
  description = "ID of the dedicated private-endpoints subnet in the spoke VNet"
  type        = string
}

variable "acr_id" {
  description = "Resource ID of the ACR this endpoint fronts"
  type        = string
}

variable "private_dns_zone_id" {
  description = "ID of the privatelink.azurecr.io private DNS zone used for name resolution"
  type        = string
}