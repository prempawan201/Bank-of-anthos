variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
}

variable "hub_cidr" {
  description = "Address space for the hub VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "your_home_ip" {
  description = "Your public IP for SSH to agent VM (CIDR, e.g. 1.2.3.4/32)"
  type        = string
}

variable "log_analytics_name" {
  description = "Central Log Analytics workspace name"
  type        = string
}

variable "agent_vm_name" {
  type = string
}

variable "agent_vm_size" {
  description = "Agent VM size. B2s is the cheap default."
  type        = string
  default     = "Standard_B2s"
}

variable "agent_ssh_public_key" {
  description = "Contents of ~/.ssh/id_ed25519.pub"
  type        = string
}

variable "azdo_org_url" {
  type = string
}

variable "azdo_pool_name" {
  type    = string
  default = "boa-self-hosted"
}

# Agent registration PAT. Delivered via TF_VAR_azdo_pat — a SECRET
# pipeline variable in tf-platform — and rendered into the agent VM's
# cloud-init customData. NOT read from any Key Vault (that would invert
# the hub→spoke dependency). NEVER set in terraform.tfvars or committed.
# default = "" so non-hub plans don't demand it; the cloud-init guard
# catches an empty value at boot.
variable "azdo_pat" {
  description = "Agent registration PAT, from TF_VAR_azdo_pat secret pipeline variable. Rendered into agent VM cloud-init customData."
  type        = string
  sensitive   = true
  default     = ""
}