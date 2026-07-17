variable "environment" {
  description = "Environment name: dev | qa | staging | prod"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to every resource (merged with lifecycle = ephemeral)"
  type        = map(string)
}

variable "spoke_cidr" {
  description = "Address space for the spoke VNet. Must not overlap hub or other spokes."
  type        = string
}

variable "subnet_cidrs" {
  description = "Map of the four subnet CIDRs within the spoke VNet"
  type = object({
    aks_nodes         = string
    postgres          = string
    private_endpoints = string
    ingress           = string
  })
}

variable "resource_group_name" {
  description = "RG that holds the spoke VNet (ephemeral workload RG)"
  type        = string
}

# Peering posture lever. Default true keeps staging/prod peered when
# they pass nothing; dev sets false for a standalone VNet.
variable "enable_peering" {
  description = "Peer the spoke to the hub. False for standalone dev."
  type        = bool
  default     = true
}

variable "hub_vnet_id" {
  description = "ID of the hub VNet (from remote_state). Empty when peering disabled."
  type        = string
  default     = ""
}

variable "hub_vnet_name" {
  description = "Name of the hub VNet. Empty when peering disabled."
  type        = string
  default     = ""
}

variable "hub_resource_group_name" {
  description = "RG holding the hub VNet. Empty when peering disabled."
  type        = string
  default     = ""
}
#Plat 9.2 lever: public ingress.
variable "enable_public_http_ingress" {
  type        = bool
  default     = false   # fail-closed: staging/prod inherit deny
  description = "Dev-only. Admits inbound TCP 80 from Internet on the AKS node NSG for a public LoadBalancer frontend."
}