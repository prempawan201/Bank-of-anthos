variable "name" {
  description = "Globally unique ACR name (5-50 chars, alphanumeric only)"
  type        = string
}

variable "resource_group_name" {
  description = "RG the registry is created in — the environment's own workload RG"
  type        = string
}

variable "location" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

# SKU is the main dev-vs-prod lever for this module.
# Default Premium keeps staging/prod safe when they pass nothing;
# dev explicitly overrides to "Basic".
variable "sku" {
  description = "ACR SKU. Basic for dev; Premium required for private endpoints (staging/prod)."
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

# Public posture lever.
#   dev      → true  (hosted agent + local pulls reach it directly)
#   staging/ → false (locked to private endpoint)
#   prod
variable "public_network_access_enabled" {
  description = "true = reachable over public internet (dev); false = private-endpoint-only (staging/prod)"
  type        = bool
  default     = true
}

# Optional observability hook. null in dev (no hub workspace);
# set in staging/prod to the hub Log Analytics workspace.
variable "log_analytics_workspace_id" {
  description = "If set, creates a diagnostic setting sending ACR logs to this LA workspace"
  type        = string
  default     = null
}