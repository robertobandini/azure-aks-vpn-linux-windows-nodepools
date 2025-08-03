resource "azurerm_private_dns_zone" "aks_dns_zone" {
  name                = "${local.environment}.privatelink.${local.location}.azmk8s.io"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks_dns_zone_network_link_platform" {
  name                  = azurerm_virtual_network.vnet.name
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.aks_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = local.tags

  depends_on = [
    azurerm_private_dns_zone.aks_dns_zone
  ]
}

resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "aks-${local.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "aks_dns_zone_contributor" {
  scope                = azurerm_private_dns_zone.aks_dns_zone.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_virtual_network.vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

resource "azurerm_kubernetes_cluster" "aks" {
  location                          = local.location
  resource_group_name               = azurerm_resource_group.rg.name
  name                              = local.environment
  kubernetes_version                = local.kubernetes_version
  sku_tier                          = "Standard"
  dns_prefix                        = local.environment
  private_dns_zone_id               = azurerm_private_dns_zone.aks_dns_zone.id
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  private_cluster_enabled           = true

  default_node_pool {
    name                 = "default"
    vnet_subnet_id       = azurerm_subnet.aks.id
    zones                = [1, 2, 3]
    auto_scaling_enabled = true
    orchestrator_version = local.kubernetes_version
    vm_size              = "Standard_D2_v3"
    os_disk_type         = "Managed"
    os_disk_size_gb      = 50
    min_count            = 1
    max_count            = 10
    tags                 = local.tags

    upgrade_settings {
      drain_timeout_in_minutes = 0
      max_surge = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }  

  tags = local.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "lnx" {
  name                  = "lnx"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vnet_subnet_id        = azurerm_subnet.aks.id
  zones                 = [1, 2, 3]
  auto_scaling_enabled  = true
  orchestrator_version  = local.kubernetes_version
  os_type               = "Linux"
  priority              = "Regular"
  vm_size               = "Standard_D2_v3"
  os_disk_type          = "Managed"
  os_disk_size_gb       = 50
  min_count             = 1
  max_count             = 10
  node_labels           = { nodegroup = "lnx" }
  node_taints           = ["type=lnx:NoSchedule"]
  tags                  = local.tags

  upgrade_settings {
    drain_timeout_in_minutes = 0
    max_surge = "10%"
    node_soak_duration_in_minutes = 0
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "win" {
  name                  = "win"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vnet_subnet_id        = azurerm_subnet.aks.id
  zones                 = [1, 2, 3]
  auto_scaling_enabled  = true
  orchestrator_version  = local.kubernetes_version
  os_type               = "Windows"
  os_sku                = "Windows2019"
  priority              = "Regular"
  vm_size               = "Standard_D2_v3"
  os_disk_type          = "Managed"
  os_disk_size_gb       = 50
  min_count             = 1
  max_count             = 10
  node_labels           = { nodegroup = "win" }
  node_taints           = ["type=win:NoSchedule"]
  tags                  = local.tags

  upgrade_settings {
    drain_timeout_in_minutes = 0
    max_surge = "10%"
    node_soak_duration_in_minutes = 0
  }
}