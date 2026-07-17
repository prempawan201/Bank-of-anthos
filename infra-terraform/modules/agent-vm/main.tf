# ============================================================
# modules/agent-vm — Self-hosted Azure DevOps agent VM
# ------------------------------------------------------------
# STAGING/PROD ONLY. In-VNet pipeline agent for deploying private
# clusters / private endpoints that hosted agents can't reach.
#
# Dual auth mode via var.agent_auth_mode:
#   "pat"              → PAT delivered via cloud-init customData
#                        (var.azdo_pat, secure pipeline variable).
#                        No Key Vault read. Proven, default.
#   "managed_identity" → VM's user-assigned identity authenticates
#                        to Azure DevOps. Requires one-time ADO-org
#                        enrollment of the UAMI (see README) — if
#                        missing, registration is REJECTED by ADO.
#
# Selectable mode, NOT runtime failover — pick, apply; no fallback.
# ============================================================

locals {
  use_pat = var.agent_auth_mode == "pat"
  use_mid = var.agent_auth_mode == "managed_identity"

  cloud_init = templatefile("${path.module}/cloud-init.yaml", {
    admin_user = var.admin_username
    azdo_url   = var.azdo_org_url
    azdo_pool  = var.azdo_pool_name
    auth_mode  = var.agent_auth_mode
    # PAT-only input — the registration PAT, rendered into customData.
    # Empty string in MID mode (template branches on auth_mode).
    azdo_pat = local.use_pat ? var.azdo_pat : ""
    # MID-only input — the UAMI client_id the agent presents to ADO.
    uami_client_id = local.use_mid ? azurerm_user_assigned_identity.agent[0].client_id : ""
  })
}

# ---- User-assigned identity (MID mode only) ----
# MID mode needs a STABLE client_id known before boot, so it can be
# pre-registered in the ADO org. System-assigned wouldn't exist
# until VM create and can't be pre-registered. Gated — not created
# in PAT mode.
resource "azurerm_user_assigned_identity" "agent" {
  count               = local.use_mid ? 1 : 0
  name                = "id-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.common_tags
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "agent" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.common_tags

  network_interface_ids = [azurerm_network_interface.vm.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Identity type depends on mode:
  #   PAT → SystemAssigned. Not used for registration (PAT comes via
  #         customData); kept so staging can grant this principal
  #         Secrets User on the STAGING KV for deploy-time reads.
  #   MID → UserAssigned (stable client_id, pre-registered in ADO).
  dynamic "identity" {
    for_each = local.use_pat ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }
  dynamic "identity" {
    for_each = local.use_mid ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.agent[0].id]
    }
  }

  custom_data = base64encode(local.cloud_init)
}

# NOTE: the former azurerm_role_assignment.vm_kv_read and
# time_sleep.wait_for_kv_rbac resources are REMOVED. PAT mode no
# longer reads a Key Vault for registration, so the VM identity
# needs no KV grant here. The agent's deploy-time KV access lives
# in the STAGING root (agent_kv_secrets_user, granted on the
# staging KV via hub's agent_principal_id output) — downward and
# correct.