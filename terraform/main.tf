resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "lab"
    project     = "aks-terraform-cicd"
  }
}

resource "random_string" "acr_suffix" {
  length  = 5
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_container_registry" "lab" {
  name                = "${var.acr_name_prefix}${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = {
    environment = "lab"
    project     = "aks-terraform-cicd"
  }
}
