# ── Core ─────────────────────────────────────────────────────
variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "common_tags" {
  type = map(string)
}

# ── Networking ───────────────────────────────────────────────
variable "resource_group_name" {
  description = "Prod workload RG — owned by spoke-networking module"
  type        = string
}

variable "spoke_cidr" {
  type = string
}

# Must match the object shape in modules/spoke-networking/variables.tf exactly.
# Four keys required: aks_nodes, postgres, private_endpoints, ingress.
# private_endpoints subnet is created by the module but unused in prod
# (no PEs) — included to satisfy the module's type constraint.
variable "subnet_cidrs" {
  type = object({
    aks_nodes         = string
    postgres          = string
    private_endpoints = string
    ingress           = string
  })
}

# ── ACR ──────────────────────────────────────────────────────
variable "acr_name" {
  description = "Globally unique ACR name"
  type        = string
}

# ── Key Vault ────────────────────────────────────────────────
variable "keyvault_name" {
  description = "Globally unique KV name"
  type        = string
}

variable "admin_object_id" {
  description = "Object ID granted Key Vault Administrator. Use prod SP object ID (GATE A)."
  type        = string
}

# ── AKS ──────────────────────────────────────────────────────
variable "aks_name" {
  type = string
}

variable "aks_dns_prefix" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

# Load-bearing: agent VM IP is the CD path into the public API.
# Empty list = API open to the entire internet. GATE C.
variable "aks_authorized_ip_ranges" {
  description = "Laptop IP/32 + hub agent VM IP/32. GATE C."
  type        = list(string)
}

variable "aks_sku_tier" {
  type    = string
  default = "Free"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.aks_sku_tier)
    error_message = "aks_sku_tier must be Free, Standard, or Premium."
  }
}

variable "user_node_pools" {
  type = map(object({
    vm_size              = string
    node_count           = number
    min_count            = number
    max_count            = number
    auto_scaling_enabled = bool
    os_disk_size_gb      = number
    node_labels          = map(string)
    node_taints          = list(string)
    mode                 = string
  }))
  default = {}
}

# ── Postgres ─────────────────────────────────────────────────
variable "postgres_name" {
  type = string
}

variable "postgres_admin_login" {
  type    = string
  default = "pgadmin"
}

variable "postgres_sku" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgres_backup_retention_days" {
  type    = number
  default = 7
  validation {
    condition     = var.postgres_backup_retention_days >= 7 && var.postgres_backup_retention_days <= 35
    error_message = "Backup retention must be 7–35 days."
  }
}

variable "postgres_geo_redundant_backup" {
  type    = bool
  default = false
}

# ── Identity ─────────────────────────────────────────────────
variable "platform_sp_object_id" {
  description = "Prod SP object ID (sc-boa-prod WIF, manual mode). KV Secrets Officer + Postgres AD admin. GATE A."
  type        = string
}

variable "prod_sp_display_name" {
  description = "Prod SP display name. Must match platform_sp_object_id — Postgres AD admin requires both to resolve to the same principal. GATE A."
  type        = string
}

# variable "prod_ci_sp_object_id" {
#   description = "sc-boa-acr-prod service connection SP object ID. Granted AcrPush. GATE E."
#   type        = string
# }

variable "prod_ci_sp_object_id" {
  description = "sc-boa-acr-prod SP object ID. Granted AcrPush. GATE E. Empty until SC created post-apply."
  type        = string
  default     = ""
}