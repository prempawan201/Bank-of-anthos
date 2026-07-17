variable "name" {
  description = "Log Analytics workspace name"
  type        = string
}

variable "resource_group_name" {
  description = "RG holding the workspace — the hub RG (persistent)"
  type        = string
}

variable "location" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "sku" {
  description = "Pricing SKU. PerGB2018 = pay-per-GB ingested (the standard model)."
  type        = string
  default     = "PerGB2018"
}

variable "retention_in_days" {
  description = "Data retention. 30 days is the included tier; longer retention adds cost."
  type        = number
  default     = 30
}