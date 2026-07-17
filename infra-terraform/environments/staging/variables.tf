variable "subscription_id" { type = string }
variable "tenant_id" { type = string }

variable "environment" {
  type    = string
  default = "staging"
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "resource_group_name" {
  description = "Staging workload RG"
  type        = string
}

variable "common_tags" {
  type = map(string)
}

variable "spoke_cidr" {
  description = "Staging VNet space (10.20.0.0/16 — no overlap with hub/dev/prod)"
  type        = string
}

variable "subnet_cidrs" {
  type = object({
    aks_nodes         = string
    postgres          = string
    private_endpoints = string
    ingress           = string
  })
}

variable "acr_name" {
  description = "Globally unique ACR name (Premium, built inline)"
  type        = string
}

variable "keyvault_name" {
  description = "Globally unique KV name"
  type        = string
}

variable "admin_object_id" {
  description = "Human admin object ID — Key Vault Administrator"
  type        = string
}

variable "platform_sp_object_id" {
  description = "Pipeline SP object ID — Secrets Officer + Postgres AD admin"
  type        = string
}

variable "aks_name" { type = string }
variable "aks_dns_prefix" { type = string }
variable "kubernetes_version" { type = string }

variable "postgres_name" {
  description = "Globally unique Postgres server name"
  type        = string
}

variable "postgres_admin_login" {
  type    = string
  default = "pgadmin"
}

variable "postgres_sku" {
  type    = string
  default = "B_Standard_B1ms"
}