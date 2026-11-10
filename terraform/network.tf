resource "azurerm_virtual_network" "lab" {
  name                = "vnet-aks-lab"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  tags = {
    environment = "lab"
    project     = "aks-terraform-cicd"
  }
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "snet-aks-nodes"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.1.0/24"]
}
