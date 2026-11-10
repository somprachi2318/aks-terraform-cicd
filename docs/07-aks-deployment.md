# AKS Deployment

This guide explains the AKS configuration in the project's Terraform files and the deployment lessons for this learning lab. The commands below are examples for Windows PowerShell; they were not run while creating this guide.

> Run Terraform commands from the `terraform` folder. Before using Azure CLI or Terraform, sign in to the intended Azure account and subscription. AKS nodes, disks, load balancer resources, and other infrastructure can incur Azure charges while they exist.

## 1. Why did we create an AKS cluster?

Azure Kubernetes Service (AKS) is Azure's managed Kubernetes service. It runs containerized applications and helps manage the Kubernetes control plane. This project creates an AKS cluster so the Flask application can eventually run as a container in Azure, with Kubernetes managing the application workload.

Creating the cluster does not deploy the Flask application by itself. A Kubernetes workload and a container image reference are still needed to run the application.

## 2. What are the control plane and worker nodes?

- **Control plane:** The managed Kubernetes components that keep track of the cluster and coordinate work, such as scheduling pods onto nodes. Azure manages the AKS control plane.
- **Worker node:** An Azure virtual machine that runs the Kubernetes node software and application pods. This project configures one system worker node.
- **Pod:** The Kubernetes unit that runs one or more application containers.

Simple picture:

```text
Azure
└── Resource Group: rg-aks-cicd-lab (Central India)
    ├── AKS control plane: aks-cicd-lab
    │   └── User-assigned identity: id-aks-cicd-lab
    │       └── Network Contributor on the AKS subnet
    ├── Worker node pool: 1 x Standard_D2s_v5
    │   └── Runs Kubernetes system and application pods
    ├── VNet and AKS subnet
    └── Existing ACR
        └── AcrPull granted to the AKS kubelet identity
```

The diagram shows the resources and permissions described in Terraform. The identity used by the AKS control plane and the kubelet identity used to pull images are different identities.

## 3. AKS settings in this project

The AKS cluster and its role assignments are in `terraform/aks.tf`. The Resource Group and region are supplied by the existing Terraform configuration and `terraform/terraform.tfvars`.

| Setting | Project value |
|---|---|
| Cluster name | `aks-cicd-lab` |
| Resource Group | `rg-aks-cicd-lab` |
| Region | `centralindia` (Central India) |
| AKS tier | `Free` |
| System node count | `1` |
| Worker VM size | `Standard_D2s_v5` |
| Node OS disk | `30` GB |
| Node autoscaling | Disabled |
| Control-plane identity | User-assigned identity `id-aks-cicd-lab` |
| Network | Azure CNI Overlay |
| OIDC issuer | Enabled |
| Workload Identity | Enabled |
| Local Kubernetes accounts | Not disabled |

### Kubernetes version

The deployment was reported as using Kubernetes `1.36`. In the current `terraform/aks.tf`, `kubernetes_version` is not set. This means the configuration lets Azure choose a supported default when creating the cluster; Terraform also exposes the selected value through the `aks_kubernetes_version` output. The version may therefore differ if Azure selects another default during a future creation.

The cluster definition includes these key settings:

```hcl
resource "azurerm_kubernetes_cluster" "lab" {
  name                = "aks-cicd-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_tier            = "Free"

  default_node_pool {
    name                 = "system"
    node_count           = 1
    vm_size              = "Standard_D2s_v5"
    os_disk_size_gb      = 30
    auto_scaling_enabled = false
    vnet_subnet_id       = azurerm_subnet.aks_nodes.id
  }
}
```

The full resource also configures the managed identity, network profile, OIDC issuer, and Workload Identity.

## 4. Why use a user-assigned managed identity?

The Terraform configuration creates `id-aks-cicd-lab` before creating AKS. A user-assigned identity is a separate Azure resource that can be created and given permissions before the cluster is created. That lets Terraform grant subnet access first and then make AKS wait for that permission.

Managed identities avoid placing a client secret or password in the Terraform configuration. Azure manages the identity's credentials. The AKS control plane uses this identity when it needs to manage Azure resources.

## 5. Why are Network Contributor and AcrPull needed?

### Network Contributor

The AKS control-plane identity receives `Network Contributor` on the existing AKS subnet. AKS needs permission to manage the network resources required for the nodes that use this subnet.

Terraform scopes this permission to the subnet rather than granting it to the whole Resource Group or subscription. The AKS resource has an explicit `depends_on` for this role assignment, so Terraform completes the role assignment before it creates the cluster.

### AcrPull

The AKS kubelet identity receives `AcrPull` on the existing `azurerm_container_registry.lab`. The kubelet identity is used by the node when it needs to pull a container image from ACR. Terraform gets this identity from the AKS resource, so the role assignment is created after AKS.

Role assignments can take time to propagate in Azure. The deployment identity running Terraform must also be allowed to create role assignments at the relevant scopes.

## 6. Why are OIDC issuer and Workload Identity enabled?

The OIDC issuer provides an identity endpoint for the AKS cluster. Workload Identity lets an application running in a pod use a federated identity to access supported Azure resources without storing an Azure client secret in the pod.

Both settings are enabled in `terraform/aks.tf`. They prepare the cluster for pod-to-Azure identity, but an application still needs its own federated credential and appropriate Azure role assignments before it can access a resource. This is separate from the AKS control-plane identity and the kubelet identity.

## 7. Terraform commands

Before running Terraform, sign in to the correct Azure account and provide the `subscription_id` input as described in `docs/03-terraform.md`. In PowerShell, move into the Terraform folder:

```powershell
Set-Location .\terraform
```

This sets the working folder so Terraform uses the project's configuration and local state.

### Validate the configuration

```powershell
terraform validate
```

This checks the Terraform files for syntax and internal configuration errors. It does not create Azure resources.

### Review the proposed changes

```powershell
terraform plan
```

This compares the Terraform configuration with Terraform's state and Azure, then shows the changes Terraform proposes. Read the plan carefully before approving any changes. Do not approve a plan that unexpectedly replaces or deletes existing resources.

### Apply after reviewing the plan

```powershell
terraform apply
```

This shows a plan and asks for confirmation before creating or changing resources. Run it only after reviewing the plan and confirming it matches your intent. This guide does not run `terraform apply` or `terraform destroy`.

## 8. Deployment lesson: VM size availability

The first AKS deployment attempt used `Standard_D2s_v3`. Azure reported that this size was not allowed for the subscription in Central India. VM availability can depend on subscription quota, regional capacity, and subscription or policy restrictions.

The node size in the current `terraform/aks.tf` is `Standard_D2s_v5`. Changing the configured VM size to `Standard_D2s_v5` resolved the reported size restriction for the retry. Check the current subscription's quota and allowed VM sizes before a future deployment; availability can change.

## 9. Check before safely retrying a deployment

Before retrying after an interrupted or failed deployment, check both Terraform's state and Azure:

```powershell
terraform state list
```

This lists the resources Terraform currently tracks in its local state. It helps show whether Terraform recorded the AKS cluster and related resources. It does not query Azure directly, and an empty result does not prove that no Azure resource exists.

Check Azure for AKS clusters in the project's Resource Group:

```powershell
az aks list `
  --resource-group rg-aks-cicd-lab `
  --output table
```

This asks Azure for the AKS clusters that currently exist in that Resource Group. It helps identify a cluster that may have been created even if a Terraform run did not finish cleanly.

Together, these checks help avoid blindly retrying and accidentally creating a duplicate or conflicting cluster. If Azure shows a resource that Terraform does not track, stop and reconcile the configuration and state before applying again. Do not remove state files or import resources unless you understand the consequences and have reviewed the correct Terraform procedure.

## 10. Connect to AKS and verify the worker node

After the cluster exists, get its credentials and inspect the node:

```powershell
az aks get-credentials `
  --resource-group rg-aks-cicd-lab `
  --name aks-cicd-lab

kubectl get nodes -o wide
```

- `az aks get-credentials` adds the cluster credentials and context to the local Kubernetes configuration. You need Azure permission to retrieve the cluster credentials.
- `kubectl get nodes -o wide` asks the Kubernetes API for the nodes and displays extra details, including their addresses. Confirm that the system node is listed and is `Ready`.

If you have more than one Kubernetes cluster configured locally, check the current context before running commands against a cluster:

```powershell
kubectl config current-context
```

## Troubleshooting lessons

### The VM size is rejected

The original `Standard_D2s_v3` was not allowed for this subscription in Central India. The current configuration uses `Standard_D2s_v5`. Check quota, regional availability, and any subscription policies before planning another change.

### A retry may find an existing cluster

Use both `terraform state list` and `az aks list --resource-group rg-aks-cicd-lab --output table`. Terraform state shows what Terraform tracks; Azure CLI shows what Azure reports as existing. If the results disagree, investigate before applying again.

### Terraform cannot assign a role

Confirm the identity running Terraform has permission to create role assignments on the subnet and ACR. Also confirm that the cluster depends on the subnet role assignment and allow time for Azure RBAC changes to propagate.

### `kubectl` cannot connect or shows no nodes

Confirm the cluster exists, your Azure CLI session is using the intended subscription, and `az aks get-credentials` completed successfully. Check `kubectl config current-context`, then run `kubectl get nodes -o wide` again.

### Remember Azure costs

The AKS Free tier does not make the worker VM and its supporting infrastructure free. Worker nodes, OS disks, load balancer resources, networking, registry storage, and data transfer may incur charges. Check current Azure pricing and remove resources only through a carefully reviewed process when the lab is no longer needed.
