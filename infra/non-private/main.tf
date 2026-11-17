data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}

data "azapi_resource" "storage" {
  type                   = "Microsoft.Storage/storageAccounts@2023-05-01"
  resource_id            = "${data.azurerm_resource_group.existing.id}/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name}"
  response_export_values = ["name"]
}

data "azapi_resource" "foundry" {
  type                   = "Microsoft.CognitiveServices/accounts@2025-06-01"
  resource_id            = "${data.azurerm_resource_group.existing.id}/providers/Microsoft.CognitiveServices/accounts/${var.foundry_account_name}"
  response_export_values = ["name"]
}

data "azapi_resource" "search" {
  type                   = "Microsoft.Search/searchServices@2025-05-01"
  resource_id            = "${data.azurerm_resource_group.existing.id}/providers/Microsoft.Search/searchServices/${var.search_service_name}"
  response_export_values = ["name"]
}

data "azuread_client_config" "current" {}

resource "azurerm_databricks_workspace" "workshop" {
  name                        = var.workspace_name
  resource_group_name         = data.azurerm_resource_group.existing.name
  location                    = data.azurerm_resource_group.existing.location
  sku                         = "premium"
  managed_resource_group_name = "rg-${var.workspace_name}-managed"
  tags                        = merge(var.tags, { SecurityControl = "Ignore" })

  public_network_access_enabled         = true
  network_security_group_rules_required = "AllRules"

  custom_parameters {
    no_public_ip = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azuread_application" "notebooks" {
  display_name = var.principal_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "notebooks" {
  client_id = azuread_application.notebooks.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azapi_resource" "containers" {
  for_each  = toset([var.input_container_name, var.output_container_name])
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = each.value
  parent_id = "${data.azapi_resource.storage.id}/blobServices/default"
  body = {
    properties = {
      publicAccess = "None"
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}

locals {
  notebook_roles = {
    analyze = {
      scope = data.azapi_resource.foundry.id
      role  = "Cognitive Services User"
    }
    openai = {
      scope = data.azapi_resource.foundry.id
      role  = "Cognitive Services OpenAI User"
    }
    search_data = {
      scope = data.azapi_resource.search.id
      role  = "Search Index Data Contributor"
    }
    input_read = {
      scope = azapi_resource.containers[var.input_container_name].id
      role  = "Storage Blob Data Reader"
    }
    output_write = {
      scope = azapi_resource.containers[var.output_container_name].id
      role  = "Storage Blob Data Contributor"
    }
  }
}

resource "azurerm_role_assignment" "notebook_access" {
  for_each                         = local.notebook_roles
  scope                            = each.value.scope
  role_definition_name             = each.value.role
  principal_id                     = azuread_service_principal.notebooks.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "index_setup" {
  count                            = var.enable_index_setup_role ? 1 : 0
  scope                            = data.azapi_resource.search.id
  role_definition_name             = "Search Service Contributor"
  principal_id                     = azuread_service_principal.notebooks.object_id
  skip_service_principal_aad_check = true
}
