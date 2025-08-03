resource "azurerm_resource_group" "rg" {
  name     = local.environment
  location = local.location
  tags     = local.tags
}