# Terraform and the Azure Resource Group

This guide explains the Terraform configuration and the Resource Group deployment completed for this learning project. The documented commands are for reference only; they were not run while creating this guide.

## What is Terraform?

Terraform is a tool for describing infrastructure in configuration files. This is called **Infrastructure as Code (IaC)**.

With IaC, the desired resources are written down and can be reviewed and managed consistently. In this project, the Terraform configuration describes one Azure Resource Group. It does not declare an AKS cluster, container registry, network, or any other Azure resource.

## The Terraform files

The Terraform files are in the `terraform` folder.

### `providers.tf`

This file sets the Terraform version requirement and selects the official `hashicorp/azurerm` provider. The configuration accepts AzureRM provider versions from 4.2 up to, but not including, 5.0. It also configures the AzureRM `features {}` block and passes the subscription ID from the `subscription_id` variable.

The AzureRM provider is Terraform's plugin for managing Azure resources. It uses Azure CLI authentication when Terraform is run with an Azure CLI session signed in to the intended account. No credentials or subscription ID are stored in this file.

### `main.tf`

This file describes the Azure Resource Group:

- Name: `rg-aks-cicd-lab`
- Region: `centralindia`
- Tags: `environment = "lab"` and `project = "aks-terraform-cicd"`

The values for the name and region come from variables rather than being repeated in the resource definition.

### `variables.tf`

This file declares the inputs used by the configuration:

- `resource_group_name` — the Resource Group name.
- `location` — the Azure region.
- `subscription_id` — the Azure subscription Terraform should target.

The subscription ID is an input and is not hardcoded in the provider configuration.

### `terraform.tfvars`

This file sets `resource_group_name` to `rg-aks-cicd-lab` and `location` to `centralindia`.

It intentionally does not contain a subscription ID. The root `.gitignore` excludes `terraform.tfvars` and other tfvars files, so values in them are not added to Git by default.

### `outputs.tf`

This file defines the values Terraform displays after an apply: the Resource Group's name and Azure resource ID.

### `.terraform.lock.hcl`

Terraform created this lock file when the provider was initialized. It records the selected AzureRM provider version, `4.81.0`, and package checksums so future initializations can use the same provider build. The root `.gitignore` does not exclude this file. It should normally be committed to Git so other users and automation can use the same provider selection.

## Supplying the subscription ID

The Terraform variable is named `subscription_id`. For AzureRM provider version 4, set the subscription ID explicitly so Terraform knows the target subscription. The project keeps the ID out of its committed configuration.

In Windows PowerShell, provide your own subscription ID in the current shell before running Terraform:

```powershell
$env:TF_VAR_subscription_id = "<your-subscription-id>"
```

Replace the placeholder locally; do not put a real subscription ID or credentials in this documentation or in a committed file. Terraform maps the `TF_VAR_subscription_id` environment variable to the `subscription_id` input variable.

Azure CLI supplies the authentication context. If you are not already signed in, the usual interactive sign-in command is:

```powershell
az login
```

Make sure the Azure CLI session is set to the intended subscription before using Terraform. The ID is not included here.

## Terraform workflow

Run these commands from the `terraform` folder, after supplying the subscription ID and signing in to Azure CLI. They explain the workflow and are not executed as part of this documentation.

### Initialize

```powershell
terraform init
```

Initializes the working folder, downloads the required provider, and creates or updates `.terraform.lock.hcl`.

### Validate

```powershell
terraform validate
```

Checks that the Terraform configuration is syntactically valid and internally consistent. It does not create Azure resources.

### Review a plan

```powershell
terraform plan
```

Compares the configuration with Terraform's state and Azure, then shows the changes Terraform proposes. Review the plan before approving any changes.

### Apply the plan

```powershell
terraform apply
```

Creates or updates the resources to match the configuration after displaying a plan and requesting confirmation. For the completed project setup, the intended result was the one Resource Group listed above.

## Completed deployment and verification

The completed deployment for this project is the Resource Group `rg-aks-cicd-lab` in `centralindia`. It was verified in the Azure Portal, as reported for this project. No other Azure resources are part of this completed deployment.

The Terraform outputs are intended to show the Resource Group name and ID after applying the configuration.

## Terraform state

Terraform state is a record Terraform uses to connect configuration to real resources and determine what changes are needed. This configuration does not define a remote backend, so Terraform uses its default local state.

State files must not be committed to GitHub. They can contain sensitive values and resource metadata, and sharing one carelessly can expose information or interfere with another user's Terraform operations. This project's root `.gitignore` excludes `*.tfstate` and `*.tfstate.*`. Protect state files and use an appropriately secured remote backend if the project later needs shared team state.

The lock file `.terraform.lock.hcl` is different from state: it records provider selection and checksums, and should not be confused with a secret state file.

## Common troubleshooting commands

Use the following commands when diagnosing issues. Run Terraform commands from the `terraform` folder and make sure Azure CLI is signed in.

**Check the Azure CLI account context:**

```powershell
az account show
```

**Sign in to Azure CLI if necessary:**

```powershell
az login
```

**Initialize or refresh provider installation and lock information:**

```powershell
terraform init
```

**Check configuration syntax and consistency:**

```powershell
terraform validate
```

**Inspect which providers Terraform configuration requires:**

```powershell
terraform providers
```

**List resources recorded in the current Terraform state:**

```powershell
terraform state list
```

If a command reports that `subscription_id` is missing, set `TF_VAR_subscription_id` in the current PowerShell session. If authentication fails, check the Azure CLI sign-in and subscription context. Review errors and the proposed plan before applying changes.

## Future cleanup with `terraform destroy`

`terraform destroy` asks Terraform to remove resources tracked in the current state that are managed by this configuration. It is destructive and should only be used when the Resource Group and its contents are intended to be removed. Review the proposed destruction carefully and confirm the target subscription and state first.

For future reference, the command is:

```powershell
terraform destroy
```

It was not executed as part of this documentation task.

## Terraform Interview Questions

### 1. What is Infrastructure as Code?

**Answer:** Infrastructure as Code means describing infrastructure in files so it can be reviewed, repeated, and managed with tools such as Terraform.

### 2. What does a Terraform provider do?

**Answer:** A provider is a plugin that lets Terraform communicate with a platform. The AzureRM provider lets Terraform manage supported Azure resources.

### 3. What is the purpose of `terraform plan`?

**Answer:** It shows the changes Terraform proposes before they are applied. It helps a person review what Terraform intends to create, change, or remove.

### 4. Why is Terraform state important?

**Answer:** State helps Terraform track the relationship between configuration and real resources and decide what changes are needed.

### 5. Why should state files not be committed to GitHub?

**Answer:** State may contain sensitive values and infrastructure details. Committing it can expose information and can cause problems when multiple users manage the same resources.
