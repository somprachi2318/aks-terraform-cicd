# Azure Container Registry (ACR)

This tutorial describes the Azure Container Registry (ACR) in our existing Terraform configuration and the deployed registry details recorded for this project.

## 1. What is ACR, and why is it useful with AKS?

Azure Container Registry is a private registry for storing and managing container images. An AKS cluster needs an image registry it can reach when it starts or updates application containers. ACR is Azure's registry service and fits naturally into an Azure-based workflow.

This project has an ACR, but it does not yet have an AKS cluster or the identity and access configuration that would let AKS pull from the registry.

## 2. How an image moves from a developer to AKS

The usual flow is:

1. A developer builds a Docker image on their computer.
2. The developer tags the image with the ACR login server.
3. The developer signs in with an authorized method and pushes the image to ACR.
4. An AKS workload refers to that image. AKS pulls it from ACR when it needs to run the application.

For example, after Docker has built the local `aks-flask-app:v1` image, the following commands show the shape of the tagging and push steps. They are examples only; this project has not documented a successful push, and registry access must be configured first.

```powershell
docker tag aks-flask-app:v1 akscicd1p54c.azurecr.io/aks-flask-app:v1
docker push akscicd1p54c.azurecr.io/aks-flask-app:v1
```

Because the ACR admin account is disabled, use an authorized identity-based authentication method rather than admin credentials. No AKS access role assignment or image pull configuration is included in the current Terraform configuration.

## 3. How Terraform creates the registry name

In `terraform/main.tf`, a `random_string` resource generates a short suffix:

```hcl
resource "random_string" "acr_suffix" {
  length  = 5
  lower   = true
  upper   = false
  numeric = true
  special = false
}
```

- `length = 5` asks the provider for five characters.
- `lower = true` allows lowercase letters.
- `upper = false` disallows uppercase letters.
- `numeric = true` allows digits.
- `special = false` disallows punctuation and other special characters.
- `random_string.acr_suffix.result` is the generated string value that Terraform makes available to other configuration.

The ACR name combines the configurable prefix in `terraform/variables.tf` with the generated result:

```hcl
name = "${var.acr_name_prefix}${random_string.acr_suffix.result}"
```

The prefix defaults to `akscicd`. The random provider records its generated value in Terraform state, so it remains stable across normal plans and applies. It is not regenerated on every run.

## 4. Why must an ACR name be globally unique?

An ACR name is part of its login server address, such as `akscicd12345.azurecr.io`. Azure names registries across all customers, so another registry cannot already be using the same name. The name must also use lowercase letters and digits and meet Azure's length rules. A random suffix reduces the chance of a name collision, but only Azure can confirm availability when the registry is created.

## 5. The `azurerm_container_registry` resource

The Terraform resource in `terraform/main.tf` is:

```hcl
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
```

- `name` sets the registry name using the prefix and generated suffix.
- `resource_group_name` places the registry in the existing Terraform-managed Resource Group.
- `location` uses the Resource Group's region, which is `centralindia`.
- `sku = "Basic"` chooses the Basic service tier, appropriate for a small learning lab.
- `admin_enabled = false` disables the registry's shared admin account. This avoids relying on a broad, long-lived username and password. Authentication should instead use authorized identities with appropriate access.
- `tags` set `environment = "lab"` and `project = "aks-terraform-cicd"` to help identify and organize the resource.

## 6. Why Basic and admin disabled?

Basic is the lowest ACR service tier and is a sensible low-cost starting point for a lab. It has fewer capabilities and capacity than higher tiers, so check the current Azure pricing and feature limits before using it for production.

The admin account is disabled to avoid using shared registry credentials. This is a safer default; an identity still needs permission to push or pull images. The current configuration does not create access role assignments.

## 7. How Terraform identifies dependencies

Terraform builds a dependency graph by following references between resources. In this configuration:

- The registry's `resource_group_name` and `location` reference the Resource Group.
- Its `name` references the random string's `result`.

Terraform therefore knows it must create the Resource Group and generate the suffix before creating the registry. No manual ordering is needed.

## 8. Terraform workflow

Run these commands from the `terraform` folder, after configuring the subscription ID input and signing in to Azure CLI. These commands are documented for learning; they are not being run as part of this tutorial.

### Initialize providers

```powershell
terraform init
```

Downloads the providers required by the configuration and prepares the working directory. This includes the AzureRM provider and the Random provider.

### Validate the configuration

```powershell
terraform validate
```

Checks the Terraform files for syntax and configuration errors. It does not create Azure resources.

### Review the proposed changes

```powershell
terraform plan
```

Compares the configuration with Terraform's state and shows the changes Terraform proposes. Review this output before approving changes.

### Apply the configuration

```powershell
terraform apply
```

Shows the proposed changes and asks for confirmation before creating or updating resources. For this project, the recorded deployed resources are the Resource Group and the ACR described here.

## 9. Deployed resource details

The project reports these deployed resources:

- **Resource Group:** `rg-aks-cicd-lab`
- **ACR name:** `akscicd1p54c`
- **ACR login server:** `akscicd1p54c.azurecr.io`
- **Region:** `centralindia`
- **SKU:** Basic
- **Admin account:** disabled

The login server is the hostname used in image tags and image references.

## 10. Verify the registry in Azure Portal

1. Sign in to the [Azure Portal](https://portal.azure.com/).
2. Open **Resource groups** and select `rg-aks-cicd-lab`.
3. Find and open the Container Registry named `akscicd1p54c`.
4. Check its overview for the region and login server.
5. In the registry settings, check that the SKU is Basic and the admin user is disabled.

## 11. What `.terraform.lock.hcl` does

The `.terraform.lock.hcl` file records the selected versions and checksums for Terraform providers. This project’s lock file records AzureRM `4.81.0` and Random `3.9.1`. It helps Terraform use consistent provider builds across machines. It is not a state file or a credentials file and should normally be kept in version control.

## 12. Common troubleshooting

- **Terraform says a provider is missing:** Run `terraform init` from the `terraform` folder.
- **The subscription ID is missing:** Set `TF_VAR_subscription_id` in the current PowerShell session, then retry. Do not write the actual value into this document or commit it.
- **Azure authentication fails:** Use `az account show` to inspect the Azure CLI sign-in and subscription context. Sign in with `az login` if needed.
- **The ACR name is unavailable:** Azure requires globally unique names. If Azure reports a conflict, adjust the prefix variable and plan the change before applying it.
- **Push or pull is denied:** Check the identity being used and whether it has the required registry permissions. Admin access is disabled, and the Terraform configuration does not create role assignments.
- **Terraform proposes replacing a resource:** Read the full plan carefully. Do not apply a replacement or deletion unless it is intended.

## 13. Cleanup considerations

Terraform can remove managed resources with:

```powershell
terraform destroy
```

This is destructive. The current Terraform configuration manages both the ACR and `rg-aks-cicd-lab`; destroying them can remove the registry and its stored images as well as the Resource Group. Review the destroy plan, confirm the correct subscription and state, and make sure any needed images or data have been preserved before approving. This command is for future reference and has not been run as part of this documentation.

## 14. Interview questions

### 1. What does Azure Container Registry do?

**Answer:** ACR stores and manages container images so authorized systems, such as AKS, can retrieve them.

### 2. Why does an ACR name need to be unique?

**Answer:** The name is part of the registry's Azure login server address and must not conflict with another registry name.

### 3. Why is the admin account disabled in this configuration?

**Answer:** Disabling it avoids using shared registry credentials. Users and workloads should use authorized identities instead.

### 4. What is the purpose of the `random_string` resource?

**Answer:** It generates a short suffix used to make the registry name less likely to conflict with an existing global name.

### 5. How does Terraform know to create the Resource Group before the registry?

**Answer:** The registry refers to the Resource Group's name and location. Terraform follows those references and creates dependencies first.
