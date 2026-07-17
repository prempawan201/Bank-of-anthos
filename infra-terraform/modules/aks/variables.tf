variable "name" {
  description = "AKS cluster name (also used to derive the user-assigned identity name)"
  type        = string
}

variable "resource_group_name" {
  description = "RG the cluster is created in — the environment's workload RG"
  type        = string
}

variable "location" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS API server (3-45 chars, alphanumeric + hyphens)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g. 1.33.11)"
  type        = string
}

variable "node_subnet_id" {
  description = "Subnet ID for AKS nodes (snet-aks-nodes in the spoke VNet)"
  type        = string
}

variable "vnet_id" {
  description = "Spoke VNet ID — AKS identity gets Network Contributor here for subnet/LB operations"
  type        = string
}

# Private cluster lever. Default true keeps staging/prod safe when
# they pass nothing; dev overrides to false for a public API server.
variable "private_cluster_enabled" {
  description = "true = private API server (staging/prod); false = public API server (dev)"
  type        = bool
  default     = true
}

# Only consumed when private_cluster_enabled = true. null in dev.
variable "private_dns_zone_id" {
  description = "ID of the privatelink.<region>.azmk8s.io zone. Required for private cluster; null for public dev."
  type        = string
  default     = null
}

# Optional observability. null in dev (no hub workspace) → no oms_agent.
variable "log_analytics_workspace_id" {
  description = "If set, enables Container Insights shipping to this workspace"
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Control-plane tier. Free (dev, no SLA) | Standard (staging/prod, SLA) | Premium."
  type        = string
  default     = "Free"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard, or Premium."
  }
}

variable "default_node_pool" {
  description = "Default (system) node pool config. only_critical_addons taints it so only system pods schedule here."
  type = object({
    name                 = string
    vm_size              = string
    node_count           = number
    min_count            = number
    max_count            = number
    auto_scaling_enabled = bool
    os_disk_size_gb      = number
    only_critical_addons = bool
  })
  default = {
    name                 = "system"
    vm_size              = "Standard_D2as_v6"
    node_count           = 1
    min_count            = 1
    max_count            = 3
    auto_scaling_enabled = true
    os_disk_size_gb      = 50
    only_critical_addons = true
  }
}

variable "user_node_pools" {
  description = "Map of application node pools. Empty map = no user pools (system pool only)."
  type = map(object({
    vm_size              = string
    node_count           = number
    min_count            = number
    max_count            = number
    auto_scaling_enabled = bool
    os_disk_size_gb      = number
    node_labels          = map(string)
    node_taints          = list(string)
    mode                 = string # "User" or "System"
  }))
  default = {}
}

variable "pod_cidr" {
  description = "Overlay pod CIDR (CNI Overlay) — must not overlap VNet ranges"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Cluster service (ClusterIP) CIDR — must not overlap VNet or pod ranges"
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "kube-dns service IP — must fall within service_cidr"
  type        = string
  default     = "172.16.0.10"
}

variable "authorized_ip_ranges" {
  description = "CIDRs allowed to reach the public AKS API server. Only effective when private_cluster_enabled = false. Empty list = unrestricted."
  type        = list(string)
  default     = []
}