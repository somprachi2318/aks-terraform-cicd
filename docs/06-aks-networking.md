# AKS Networking

This guide explains the networking in this project's Terraform configuration. It describes the settings in `terraform/network.tf` and `terraform/aks.tf`. The Azure and Kubernetes commands are for reference; they were not run while creating this guide.

> Run the Azure CLI commands below in Windows PowerShell from the project folder. Replace the resource group placeholder with the name configured for your lab. The Kubernetes commands require a deployed AKS cluster, permission to access it, and `kubectl` installed.

## 1. Why does AKS need a VNet and subnet?

A Virtual Network (VNet) is a private network in Azure. A subnet is a smaller address range inside that network.

AKS needs network addresses for the computers that run its workloads. In this project, the AKS worker node is connected to a dedicated subnet in our VNet. This gives the node a place in the Azure network and lets Azure manage the network resources AKS needs.

## 2. Our VNet and subnet

The resources are declared in `terraform/network.tf`:

```hcl
resource "azurerm_virtual_network" "lab" {
  name                = "vnet-aks-lab"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "snet-aks-nodes"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.1.0/24"]
}
```

- The VNet is named `vnet-aks-lab`, and its address space is `10.10.0.0/16`.
- The subnet is named `snet-aks-nodes`, and its address range is `10.10.1.0/24`.
- The subnet range is inside the VNet range.
- Both resources use the existing `azurerm_resource_group.lab` resource and its location.

## 3. Azure CNI Overlay

The AKS cluster in `terraform/aks.tf` selects Azure CNI Overlay:

```hcl
network_profile {
  network_plugin      = "azure"
  network_plugin_mode = "overlay"
  pod_cidr            = "10.244.0.0/16"
  service_cidr        = "10.20.0.0/16"
  dns_service_ip      = "10.20.0.10"
  outbound_type       = "loadBalancer"
}
```

Azure CNI Overlay gives the AKS nodes IP addresses from the VNet subnet, while pod IP addresses come from a separate overlay range. This avoids assigning every pod an address from the VNet and makes it easier to plan node subnet space. The configuration uses `10.244.0.0/16` for pods and `10.20.0.0/16` for Kubernetes Services. These ranges do not overlap each other or the configured VNet range.

The ranges must also not overlap networks that need to communicate with this cluster, such as connected or peered networks. Choose and check these ranges carefully before deployment; changing AKS network ranges later can require replacing the cluster.

`outbound_type = "loadBalancer"` configures AKS to use its load balancer for outbound traffic. It is not the same thing as the Kubernetes Service CIDR.

### Simple network picture

```text
Resource Group
└── VNet: vnet-aks-lab (10.10.0.0/16)
    └── Subnet: snet-aks-nodes (10.10.1.0/24)
        └── AKS system node (node IP from the subnet)
            ├── Pods (Overlay IPs: 10.244.0.0/16)
            └── Kubernetes Services (virtual IPs: 10.20.0.0/16)

AKS control-plane identity: id-aks-cicd-lab
└── Network Contributor on snet-aks-nodes
```

The pod and Service ranges are separate from the VNet subnet. The identity's subnet permission lets AKS manage the network resources needed by the cluster.

## 4. Node IPs, pod IPs, and Service IPs

These are three different kinds of addresses:

| Address type | Range in this project | What it is used for |
|---|---|---|
| Node IP | From subnet `10.10.1.0/24` | Address of the Azure VM that runs the Kubernetes node. |
| Pod IP | From overlay range `10.244.0.0/16` | Address used by an individual Kubernetes pod. With Overlay, pod addresses are separate from the VNet subnet addresses. |
| Service IP | From Service range `10.20.0.0/16` | Stable, cluster-internal address used to reach a Kubernetes Service. It is not an address assigned to a VM or pod. |

The DNS service address is `10.20.0.10`. It is within the configured Service range and is used by Kubernetes DNS.

## 5. How the worker node connects to the subnet

The default system node pool sets `vnet_subnet_id` to the ID of the Terraform subnet:

```hcl
default_node_pool {
  name                 = "system"
  node_count           = 1
  vm_size              = "Standard_D2s_v5"
  os_disk_size_gb      = 30
  auto_scaling_enabled = false
  vnet_subnet_id       = azurerm_subnet.aks_nodes.id
}
```

This tells AKS to place the worker node in `snet-aks-nodes`. The current configuration has one system node, uses `Standard_D2s_v5`, and does not enable node autoscaling.

## 6. Why the AKS identity needs Network Contributor

The configuration creates the user-assigned managed identity `id-aks-cicd-lab`. AKS uses this control-plane identity when managing Azure resources for the cluster.

The identity receives the built-in `Network Contributor` role scoped to the AKS subnet. This allows AKS to perform the network operations it needs on that subnet without granting the role across the whole Resource Group or subscription.

The role assignment and cluster dependency are configured in `terraform/aks.tf`:

```hcl
resource "azurerm_role_assignment" "aks_subnet_network_contributor" {
  scope                = azurerm_subnet.aks_nodes.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_kubernetes_cluster" "lab" {
  # Other cluster settings are omitted here.

  depends_on = [
    azurerm_role_assignment.aks_subnet_network_contributor,
  ]
}
```

The explicit `depends_on` makes Terraform create the subnet permission before it creates AKS. Azure role assignments can take time to propagate, so a successful Terraform ordering does not guarantee that the permission is available immediately.

The separate `AcrPull` assignment in `terraform/aks.tf` grants the AKS kubelet identity permission to pull images from the existing ACR. Terraform can only create that assignment after the cluster exists, because the kubelet identity is provided by AKS.

## 7. How Terraform creates the network resources

Terraform reads all `.tf` files in the `terraform` folder as one configuration. The resource references form the creation order:

1. The VNet uses the existing Terraform-managed Resource Group.
2. The subnet uses the VNet and the same Resource Group.
3. The user-assigned identity uses the Resource Group.
4. The subnet role assignment references both the subnet and identity.
5. AKS references the subnet and identity, and explicitly waits for the subnet role assignment.
6. The ACR role assignment references the created AKS kubelet identity and the existing Terraform-managed ACR.

Terraform determines most ordering from these references. `depends_on` is used for the subnet permission because AKS must wait for the role assignment even though it does not use a value from the assignment itself.

## 8. Verify networking in Azure

Sign in to Azure CLI and confirm you are using the intended subscription:

```powershell
az login
az account show --output table
```

`az login` signs you in. `az account show` displays the active subscription and account so you can catch a wrong-subscription mistake before inspecting resources.

Set the Resource Group name to the value used by your Terraform lab:

```powershell
$resourceGroup = "<your-resource-group-name>"
```

This PowerShell variable avoids repeating the Resource Group name in every command. Replace the placeholder locally; it is not a literal Terraform value.

Show the VNet's name and address space:

```powershell
az network vnet show `
  --resource-group $resourceGroup `
  --name vnet-aks-lab `
  --query "{name:name,addressPrefixes:addressSpace.addressPrefixes}" `
  --output table
```

This reads the VNet from Azure and displays its address space. The backtick (`) continues a PowerShell command onto the next line.

Show the subnet's name and address prefix:

```powershell
az network vnet subnet show `
  --resource-group $resourceGroup `
  --vnet-name vnet-aks-lab `
  --name snet-aks-nodes `
  --query "{name:name,addressPrefixes:addressPrefixes}" `
  --output table
```

This checks that the subnet exists under the expected VNet and has the configured prefix.

Check role assignments scoped to the subnet:

```powershell
$subnetId = az network vnet subnet show `
  --resource-group $resourceGroup `
  --vnet-name vnet-aks-lab `
  --name snet-aks-nodes `
  --query id `
  --output tsv

az role assignment list `
  --scope $subnetId `
  --include-inherited `
  --output table
```

The first command saves the subnet's Azure resource ID. The second lists role assignments at that scope (including inherited ones). Look for `Network Contributor` assigned to the object ID of `id-aks-cicd-lab`. Role changes can take time to appear or take effect.

Show the AKS network and node-pool configuration:

```powershell
az aks show `
  --resource-group $resourceGroup `
  --name aks-cicd-lab `
  --output json
```

This reads the cluster details from Azure. In the output, check `networkProfile` for the network plugin, mode, pod CIDR, Service CIDR, and DNS Service IP. Check `agentPoolProfiles` for the node pool's VM size, count, and subnet resource ID.

## 9. Verify networking in Kubernetes

Get credentials for the cluster, then check which cluster context `kubectl` will use:

```powershell
az aks get-credentials --resource-group $resourceGroup --name aks-cicd-lab
kubectl config current-context
```

The first command adds or updates the cluster credentials in your local Kubernetes configuration. The second prints the active context; check that it is the intended AKS cluster before running Kubernetes commands.

List nodes and their network details:

```powershell
kubectl get nodes -o wide
```

This lists the Kubernetes nodes, including their internal IP addresses. These node IPs come from the Azure subnet.

List pods across all namespaces:

```powershell
kubectl get pods --all-namespaces -o wide
```

This shows pod IP addresses. With the configured Overlay networking, pod IPs come from the pod CIDR, not from the node subnet.

List Services across all namespaces:

```powershell
kubectl get services --all-namespaces -o wide
```

This shows each Kubernetes Service and its cluster-internal IP when it has one. Those Service IPs come from the Service CIDR and are different from node and pod IPs.

## Troubleshooting

### The VNet, subnet, or AKS cluster cannot be found

Check that Azure CLI is signed in to the correct subscription with `az account show --output table`. Confirm `$resourceGroup` matches the Terraform Resource Group name, then retry the relevant `az ... show` command.

### AKS fails while accessing the subnet

Confirm that the `Network Contributor` role assignment is scoped to the subnet and assigned to `id-aks-cicd-lab`. The deployment identity running Terraform must also be allowed to create role assignments. Azure role changes may need time to propagate; check the assignment again before retrying.

### Terraform reports a CIDR overlap

Compare the VNet (`10.10.0.0/16`), pod (`10.244.0.0/16`), and Service (`10.20.0.0/16`) ranges with any other networks connected to the environment. Network ranges that need to communicate must not conflict.

### `kubectl` cannot connect to the cluster

Make sure the AKS cluster is deployed, Azure CLI is signed in to the correct subscription, and the current `kubectl` context is correct. Run `az aks get-credentials` again if needed. You also need permission to access the Kubernetes API.

### A node, pod, or Service has no IP address

Check the node's status with `kubectl get nodes -o wide`, then inspect pods and Services with the commands above. Confirm the AKS network profile in `az aks show` matches the Terraform settings. A node, pod, and Service use different address ranges, so do not expect their IPs to be interchangeable.
