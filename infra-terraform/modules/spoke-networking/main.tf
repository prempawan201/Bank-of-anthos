# ============================================================
# modules/spoke-networking — Spoke VNet, subnets, NSGs, peering
# ------------------------------------------------------------
# The per-environment workload network. One module, two postures:
#   dev      → standalone VNet, enable_peering = false (no hub)
#   staging  → peered to hub, enable_peering = true (default)
#   prod     → peered to hub, enable_peering = true (default)
#
# Always builds all four subnets (aks, postgres, PE, ingress) and
# their NSGs. Dev only uses the AKS subnet; the others sit unused
# but cost nothing (subnets/NSGs are free), so they're not stripped
# — keeping the module identical across envs is simpler than forking.
#
# Tagged "ephemeral" — this is the disposable workload tier,
# destroyed and recreated freely.
# ============================================================

resource "azurerm_resource_group" "spoke" {
  name     = var.resource_group_name
  location = var.location
  tags     = merge(var.common_tags, { lifecycle = "ephemeral" })
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-workload-${var.environment}-eus2"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  address_space       = [var.spoke_cidr]
  tags                = merge(var.common_tags, { lifecycle = "ephemeral" })
}

# ---- Subnets ----------------------------------------------------------------

# AKS node subnet — the only subnet dev actually uses.
resource "azurerm_subnet" "aks_nodes" {
  name                 = "snet-aks-nodes"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.subnet_cidrs.aks_nodes]
}

# Postgres subnet — DELEGATED to Flexible Server. The delegation is
# what lets a VNet-integrated (private) Postgres join this subnet.
# Unused in dev (no Postgres there) but harmless.
resource "azurerm_subnet" "postgres" {
  name                 = "snet-postgres"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.subnet_cidrs.postgres]

  delegation {
    name = "postgres-flex-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private-endpoints subnet — where KV/ACR/etc PEs land (staging/prod).
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.subnet_cidrs.private_endpoints]
}

# Ingress subnet — for the ingress controller / LB (PLAT-5).
resource "azurerm_subnet" "ingress" {
  name                 = "snet-ingress"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.subnet_cidrs.ingress]
}

# ---- NSG: AKS nodes ---------------------------------------------------------
resource "azurerm_network_security_group" "aks_nodes" {
  name                = "nsg-aks-nodes-${var.environment}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  tags                = merge(var.common_tags, { lifecycle = "ephemeral" })
}

# Allow all intra-VNet inbound (pods/nodes/services talk freely).
resource "azurerm_network_security_rule" "aks_allow_vnet" {
  name                        = "AllowVnetInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.aks_nodes.name
}

# Allow Azure LB health probes (required for the standard LB).
resource "azurerm_network_security_rule" "aks_allow_alb" {
  name                        = "AllowAzureLoadBalancer"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.aks_nodes.name
}

## Plat 9.2 lever: Dev-only public HTTP ingress for the frontend LoadBalancer service.
# Dev-only public HTTP ingress for the frontend LoadBalancer service.
resource "azurerm_network_security_rule" "aks_allow_internet_http" {
  count                       = var.enable_public_http_ingress ? 1 : 0
  name                        = "AllowInternetHttp"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.aks_nodes.name
}

# Explicit deny-all (audit clarity over Azure's implicit 65500 deny).
resource "azurerm_network_security_rule" "aks_deny_inbound" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.aks_nodes.name
}

# NOTE: these two rules target the POSTGRES NSG but are defined here
# in the file before that NSG is declared — Terraform resolves by
# reference not order, so it's valid, just visually out of place.
# Postgres outbound to VNet on 5432 (return traffic).
resource "azurerm_network_security_rule" "postgres_allow_vnet_outbound" {
  name                        = "AllowVnetOutbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.postgres.name
}

# Postgres outbound to Azure Storage on 443 — Flexible Server needs
# Storage for WAL archiving and backups.
resource "azurerm_network_security_rule" "postgres_allow_storage_outbound" {
  name                        = "AllowStorageOutbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.postgres.name
}

resource "azurerm_subnet_network_security_group_association" "aks_nodes" {
  subnet_id                 = azurerm_subnet.aks_nodes.id
  network_security_group_id = azurerm_network_security_group.aks_nodes.id
}

# ---- NSG: Postgres ----------------------------------------------------------
resource "azurerm_network_security_group" "postgres" {
  name                = "nsg-postgres-${var.environment}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  tags                = merge(var.common_tags, { lifecycle = "ephemeral" })
}

# Allow Postgres (5432) inbound from the AKS node subnet — the app path.
resource "azurerm_network_security_rule" "postgres_allow_aks" {
  name                        = "AllowAksToPostgres"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = var.subnet_cidrs.aks_nodes
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.postgres.name
}

# Allow Postgres (5432) inbound from the hub agent subnet — admin/
# verification access from the self-hosted agent. Hardcoded to the
# hub agent CIDR (10.0.1.0/24).
# Production delta: replace with a tightly-scoped Bastion rule.
resource "azurerm_network_security_rule" "postgres_allow_agent" {
  name                        = "AllowAgentToPostgres"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.postgres.name
}

resource "azurerm_network_security_rule" "postgres_deny_inbound" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.postgres.name
}

resource "azurerm_subnet_network_security_group_association" "postgres" {
  subnet_id                 = azurerm_subnet.postgres.id
  network_security_group_id = azurerm_network_security_group.postgres.id
}

# ---- NSG: private endpoints -------------------------------------------------
resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-private-endpoints-${var.environment}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  tags                = merge(var.common_tags, { lifecycle = "ephemeral" })
}

# Allow HTTPS (443) from AKS nodes to the PEs (KV/ACR data plane).
resource "azurerm_network_security_rule" "pe_allow_aks" {
  name                        = "AllowAksToPE"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.subnet_cidrs.aks_nodes
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}

resource "azurerm_network_security_rule" "pe_deny_inbound" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

# ---- NSG: ingress (placeholder; tightened in PLAT-5) ------------------------
resource "azurerm_network_security_group" "ingress" {
  name                = "nsg-ingress-${var.environment}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  tags                = merge(var.common_tags, { lifecycle = "ephemeral" })
}

resource "azurerm_subnet_network_security_group_association" "ingress" {
  subnet_id                 = azurerm_subnet.ingress.id
  network_security_group_id = azurerm_network_security_group.ingress.id
}

# ---- Bidirectional peering to hub (gated; disabled in dev) ------------------
# count gates BOTH peerings on enable_peering. Dev passes false →
# no peering, standalone VNet. Staging/prod inherit true → peered.
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count                        = var.enable_peering ? 1 : 0
  name                         = "peer-${var.environment}-to-hub"
  resource_group_name          = azurerm_resource_group.spoke.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count                        = var.enable_peering ? 1 : 0
  name                         = "peer-hub-to-${var.environment}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}