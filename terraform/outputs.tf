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

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.lab.name
}

output "aks_cluster_id" {
  description = "Azure resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.lab.id
}

output "aks_kubernetes_version" {
  description = "Kubernetes version selected for the AKS cluster."
  value       = azurerm_kubernetes_cluster.lab.kubernetes_version
}

output "aks_fqdn" {
  description = "Public DNS name of the AKS API server."
  value       = azurerm_kubernetes_cluster.lab.fqdn
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for AKS workload identity federation."
  value       = azurerm_kubernetes_cluster.lab.oidc_issuer_url
}

output "aks_node_resource_group" {
  description = "Azure-managed resource group containing the AKS node resources."
  value       = azurerm_kubernetes_cluster.lab.node_resource_group
}

output "aks_control_plane_identity_principal_id" {
  description = "Principal ID of the AKS user-assigned control plane identity."
  value       = azurerm_kubernetes_cluster.lab.identity[0].principal_id
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet identity used for the ACR pull role assignment."
  value       = azurerm_kubernetes_cluster.lab.kubelet_identity[0].object_id
}
