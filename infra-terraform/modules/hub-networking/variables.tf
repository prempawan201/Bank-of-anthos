variable "location" {
  description = "Azure region where the hub resources are created"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all hub resources (merged with lifecycle = persistent)"
  type        = map(string)
}

variable "hub_cidr" {
  description = "CIDR block for the hub VNet. Must not overlap any spoke VNet range."
  type        = string
  default     = "10.0.0.0/16"
}

variable "resource_group_name" {
  description = "Name of the resource group holding the hub network"
  type        = string
  default     = "rg-boa-hub-eus2"
}

variable "your_home_ip" {
  description = "Your public IP for temporary SSH access to the agent VM. Removed once Bastion is deployed."
  type        = string
}