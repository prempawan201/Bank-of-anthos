variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "environment" {
  description = "Environment name: dev | qa | prod"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}

variable "location" {
  description = "Azure region (short form, e.g. eastus2)"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
}

variable "spoke_cidr" {
  type = string
}

variable "subnet_cidrs" {
  type = object({
    aks_nodes         = string
    postgres          = string
    private_endpoints = string
    ingress           = string
  })
}

variable "resource_group_name" {
  type = string
}