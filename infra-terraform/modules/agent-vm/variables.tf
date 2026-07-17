variable "name" {
  description = "VM name (e.g. vm-boa-agent-01) — also derives NIC and UAMI names"
  type        = string
}

variable "resource_group_name" {
  description = "RG the VM, NIC, and (MID mode) identity are created in — the hub RG"
  type        = string
}

variable "location" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "subnet_id" {
  description = "Hub agent subnet (snet-agent) the NIC attaches to"
  type        = string
}

variable "vm_size" {
  description = "VM size. B2s is a cheap burstable default sufficient for one agent."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Linux admin user — also the account the agent service runs as"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key contents (cat ~/.ssh/id_ed25519.pub) — key auth only"
  type        = string
}

variable "azdo_org_url" {
  description = "Azure DevOps org URL e.g. https://dev.azure.com/kprempawan1"
  type        = string
}

variable "azdo_pool_name" {
  description = "Azure DevOps self-hosted agent pool the VM registers into"
  type        = string
  default     = "boa-self-hosted"
}

# ---- The auth-mode toggle ----
variable "agent_auth_mode" {
  description = "How the agent authenticates to Azure DevOps: 'pat' (proven default) or 'managed_identity' (PAT-free, needs ADO-org bootstrap)."
  type        = string
  default     = "pat"
  validation {
    condition     = contains(["pat", "managed_identity"], var.agent_auth_mode)
    error_message = "agent_auth_mode must be 'pat' or 'managed_identity'."
  }
}

# ---- PAT-mode input ----
# The registration PAT, delivered via cloud-init customData (rendered
# by templatefile in main.tf). Sourced from TF_VAR_azdo_pat — a SECRET
# tf-platform pipeline variable, never committed. NOT read from Key
# Vault: that would force the hub to depend on a spoke KV (inverts the
# hub→spoke direction) and require opening a private KV to land the PAT.
# Scope the PAT to Agent Pools (Read & manage) only, short expiry.
# default = "" so plan/apply on envs that don't build the agent VM
# (dev, dns, staging spokes) don't demand a value; the cloud-init guard
# catches an empty PAT at boot in hub.
variable "azdo_pat" {
  description = "PAT mode only: agent registration PAT, delivered via customData from TF_VAR_azdo_pat secret variable. Empty in MID mode."
  type        = string
  sensitive   = true
  default     = ""
} 