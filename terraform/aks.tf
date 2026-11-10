resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-cicd-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  tags = {
    environment = "lab"
    project     = "aks-terraform-cicd"
  }
}

resource "azurerm_role_assignment" "aks_subnet_network_contributor" {
  scope                = azurerm_subnet.aks_nodes.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_kubernetes_cluster" "lab" {
  name                = "aks-cicd-lab"
  dns_prefix          = "aks-cicd-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_tier            = "Free"

  # The subnet permission must be granted before AKS uses the subnet.
  depends_on = [
    azurerm_role_assignment.aks_subnet_network_contributor,
  ]

  default_node_pool {
    name                 = "system"
    node_count           = 1
    vm_size              = "Standard_D2s_v5"
    os_disk_size_gb      = 30
    auto_scaling_enabled = false
    vnet_subnet_id       = azurerm_subnet.aks_nodes.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.20.0.0/16"
    dns_service_ip      = "10.20.0.10"
    outbound_type       = "loadBalancer"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  local_account_disabled    = false

  tags = {
    environment = "lab"
    project     = "aks-terraform-cicd"
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.lab.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.lab.kubelet_identity[0].object_id
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}
