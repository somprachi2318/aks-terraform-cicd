variable "resource_group_name" {
  description = "Name of the Azure resource group for this lab."
  type        = string
}

variable "location" {
  description = "Azure region where the resource group will be created."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID. Provide this separately; do not commit it."
  type        = string
}

variable "acr_name_prefix" {
  description = "Lowercase alphanumeric prefix for the globally unique Container Registry name."
  type        = string
  default     = "akscicd"
}
