resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "id-github-actions-cicd"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  tags = {
    environment = "lab"
    project     = "aks-terraform-cicd"
  }
}

resource "azurerm_role_assignment" "github_actions_acr_push" {
  scope                = azurerm_container_registry.lab.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "github_main" {
  name                      = "github-main-oidc"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_actions.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:somprachi2318/aks-terraform-cicd:ref:refs/heads/main"
  audience                  = ["api://AzureADTokenExchange"]
}
