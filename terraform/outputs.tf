output "resource_group_name" {
  description = "Name of the created Azure resource group."
  value       = azurerm_resource_group.lab.name
}

output "resource_group_id" {
  description = "Azure resource ID of the created resource group."
  value       = azurerm_resource_group.lab.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.lab.name
}

output "acr_login_server" {
  description = "Login server address of the Azure Container Registry."
  value       = azurerm_container_registry.lab.login_server
}
