variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "resource_group_name" {
  description = "Dev workload RG (ephemeral)"
  type        = string
}

variable "common_tags" {
  type = map(string)
}

variable "spoke_cidr" {
  description = "Dev VNet address space (10.10.0.0/16 — distinct from hub/staging/prod)"
  type        = string
}

variable "subnet_cidrs" {
  description = "The four subnet CIDRs (only aks_nodes is used in dev)"
  type = object({
    aks_nodes         = string
    postgres          = string
    private_endpoints = string
    ingress           = string
  })
}

variable "acr_name" {
  description = "Globally unique ACR name (built inline in dev)"
  type        = string
}

variable "keyvault_name" {
  description = "Globally unique KV name"
  type        = string
}

variable "admin_object_id" {
  description = "Human admin object ID — granted Key Vault Administrator"
  type        = string
}

variable "platform_sp_object_id" {
  description = "Pipeline SP object ID — granted Key Vault Secrets Officer (see review note in main.tf)"
  type        = string
}

variable "aks_name" {
  type = string
}

variable "aks_dns_prefix" {
  type = string
}

variable "kubernetes_version" {
  type = string
}