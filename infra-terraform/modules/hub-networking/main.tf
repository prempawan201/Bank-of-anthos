# ============================================================
# modules/hub-networking — Hub VNet (shared services)
# ------------------------------------------------------------
# STAGING/PROD ONLY (shared, persistent). The hub is the centre
# of the hub-and-spoke topology. It holds shared infrastructure
# that every private spoke peers into: the self-hosted agent VM,
# management/jumpbox space, and reserved subnets for future VPN
# Gateway and Bastion.
#
# Dev does not peer to the hub — dev is a standalone public VNet.
# This VNet is tagged "persistent": it outlives spoke teardowns
# because spokes depend on it for private connectivity.
# ============================================================

resource "azurerm_resource_group" "hub" {
  name     = var.resource_group_name
  location = var.location
  # persistent — never destroyed in normal dev/spoke cycles.
  tags = merge(var.common_tags, { lifecycle = "persistent" })
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-eus2"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  # 10.0.0.0/16 — the hub's own block. Spoke VNets use separate
  # /16s (dev 10.10, etc) so peering never overlaps.
  address_space = [var.hub_cidr]
  tags          = merge(var.common_tags, { lifecycle = "persistent" })
}

# ---- Subnets ----------------------------------------------------------------
# Subnet sizing rationale (why each block is the size it is):

# snet-agent — /24 (251 usable). Hosts the self-hosted agent VM(s).
# A /24 is generous for what's usually 1–2 agents, but keeps room
# to scale the pool horizontally without re-subnetting. The agent's
# IP range (10.0.1.0/24) is referenced by spoke NSG rules (e.g. the
# Postgres AllowAgentToPostgres rule), so its stability matters.
resource "azurerm_subnet" "agent" {
  name                 = "snet-agent"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

# snet-management — /24. Jumpbox / management tooling space.
# Placeholder for now (NSG below is a bare association), sized to
# match the agent subnet for consistency.
resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/24"]
}

# GatewaySubnet — /27. The name is MANDATORY and reserved by Azure:
# a VPN/ExpressRoute Gateway will ONLY deploy into a subnet named
# exactly "GatewaySubnet". /27 (30 hosts) is the Azure-recommended
# minimum that still supports gateway SKUs needing multiple IPs.
# Empty for now — reserved for future site-to-site/point-to-site VPN.
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.255.0/27"]
}

# AzureBastionSubnet — /26. Name is MANDATORY and reserved by Azure:
# Bastion ONLY deploys into a subnet named exactly "AzureBastionSubnet",
# and Azure REQUIRES /26 minimum (smaller is rejected). Reserved for
# future Bastion — the planned replacement for the temporary
# SSH-from-home rule below, giving browser-based RDP/SSH with no
# public IP on the VM.
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.254.0/26"]
}

# Note on placement: gateway (.255.0/27) and bastion (.254.0/26) are
# parked at the TOP of the /16. This deliberately keeps the low,
# contiguous ranges (.1, .2, ...) free for workload/management
# subnets to grow into without colliding with the reserved blocks.

# ---- NSG for the agent subnet ----------------------------------------------

resource "azurerm_network_security_group" "agent" {
  name                = "nsg-agent"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  tags                = merge(var.common_tags, { lifecycle = "persistent" })
}

# Temporary admin access: SSH from a single home IP. This is the
# interim path until Bastion lands. Scoped to one source IP, not
# 0.0.0.0/0 — the minimum viable exposure.
# Production delta: remove this rule once Bastion is deployed.
resource "azurerm_network_security_rule" "agent_allow_ssh_home" {
  name                        = "AllowSshFromHome"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.your_home_ip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hub.name
  network_security_group_name = azurerm_network_security_group.agent.name
}

# Allow Azure Load Balancer health probes — harmless now, needed if
# the agent is ever placed behind an internal load balancer.
resource "azurerm_network_security_rule" "agent_allow_alb" {
  name                        = "AllowAzureLoadBalancer"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hub.name
  network_security_group_name = azurerm_network_security_group.agent.name
}

# Explicit deny-all at the lowest custom priority. Azure already has
# an implicit deny at 65500; this is here for audit clarity so the
# intent ("nothing else gets in") is visible in the rule set.
resource "azurerm_network_security_rule" "agent_deny_inbound" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hub.name
  network_security_group_name = azurerm_network_security_group.agent.name
}

resource "azurerm_subnet_network_security_group_association" "agent" {
  subnet_id                 = azurerm_subnet.agent.id
  network_security_group_id = azurerm_network_security_group.agent.id
}

# ---- NSG for the management subnet (placeholder, tightened later) ----------
# Bare NSG with no custom rules yet — only Azure's implicit defaults
# apply. Associated now so the subnet is governed by an NSG from day
# one (required pattern), with real rules to be added when management
# tooling is deployed.
resource "azurerm_network_security_group" "management" {
  name                = "nsg-management"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  tags                = merge(var.common_tags, { lifecycle = "persistent" })
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

# ---- Azure Bastion ----------------------------------------------------------
# Uses the already-declared AzureBastionSubnet above. Basic SKU: the only
# target is the in-VNet agent VM (reached by private IP); spokes are operated
# from the agent shell over peering. AzureBastionSubnet has NO NSG by design —
# Basic Bastion needs none and Azure manages its platform rules.
# Production delta: this replaces the temporary AllowSshFromHome rule.

# resource "azurerm_public_ip" "bastion" {
#   name                = "pip-bas-boa-hub-eus2"
#   resource_group_name = azurerm_resource_group.hub.name
#   location            = azurerm_resource_group.hub.location
#   allocation_method   = "Static"   # Bastion requires Static
#   sku                 = "Standard"  # Bastion requires Standard
#   tags                = merge(var.common_tags, { lifecycle = "persistent" })
# }

# resource "azurerm_bastion_host" "this" {
#   name                = "bas-boa-hub-eus2"
#   resource_group_name = azurerm_resource_group.hub.name
#   location            = azurerm_resource_group.hub.location
#   sku                 = "Basic"
#   tags                = merge(var.common_tags, { lifecycle = "persistent" })

#   ip_configuration {
#     name                 = "ipcfg"
#     subnet_id            = azurerm_subnet.bastion.id   # existing subnet, declared above
#     public_ip_address_id = azurerm_public_ip.bastion.id
#   }
# }

