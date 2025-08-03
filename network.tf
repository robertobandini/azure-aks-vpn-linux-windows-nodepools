resource "azurerm_virtual_network" "vnet" {
  name                = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = local.vnet_cidrs
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = local.aks_subnet_cidrs
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = local.gateway_subnet_cidrs
}

resource "azurerm_subnet" "inbound_dns_resolver" {
  name                 = "inbound-dns-resolver"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = local.inbound_dns_resolver_subnet_cidrs

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_private_dns_resolver" "private_dns_resolver" {
  name                = local.environment
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  virtual_network_id  = azurerm_virtual_network.vnet.id
  tags                = local.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "private_dns_resolver_inbound" {
  name                    = "DNSresolver"
  private_dns_resolver_id = azurerm_private_dns_resolver.private_dns_resolver.id
  location                = azurerm_private_dns_resolver.private_dns_resolver.location
  tags                    = local.tags

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = azurerm_subnet.inbound_dns_resolver.id
  }
}

resource "azurerm_virtual_network_dns_servers" "vnet_dns_servers" {
  virtual_network_id = azurerm_virtual_network.vnet.id
  dns_servers        = [azurerm_private_dns_resolver_inbound_endpoint.private_dns_resolver_inbound.ip_configurations[0].private_ip_address]
}

resource "azurerm_public_ip" "vpn_public_ip" {
  name                = "vpn-public-ip"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  sku_tier            = "Regional"
  allocation_method   = "Static"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "vnet_gateway" {
  name                = "vnet-gateway"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  enable_bgp          = false
  sku                 = "VpnGw1AZ"
  tags                = local.tags

  ip_configuration {
    name                          = local.environment
    public_ip_address_id          = azurerm_public_ip.vpn_public_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  vpn_client_configuration {
    address_space = local.vpn_client_address_space
    root_certificate {
      name             = local.environment
      public_cert_data = local.vpn_root_certificate
    }
  }
}