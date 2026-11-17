output "databricks_workspace_id" {
  description = "Resource ID of the new Databricks workspace."
  value       = azurerm_databricks_workspace.workshop.id
}

output "databricks_workspace_url" {
  description = "Open this workspace to configure Git access, compute and secrets."
  value       = "https://${azurerm_databricks_workspace.workshop.workspace_url}"
}

output "existing_resource_group_name" {
  description = "Existing resource group; not managed by this stack."
  value       = data.azurerm_resource_group.existing.name
}

output "configuration" {
  description = "Nonsecret configuration for the Databricks stage and rehearsal tools."
  value = {
    workspace_url         = "https://${azurerm_databricks_workspace.workshop.workspace_url}"
    workspace_resource_id = azurerm_databricks_workspace.workshop.id
    tenant_id             = data.azuread_client_config.current.tenant_id
    notebook_client_id    = azuread_application.notebooks.client_id
    application_object_id = azuread_application.notebooks.object_id
    service_principal_id  = azuread_service_principal.notebooks.object_id
    storage_account_name  = var.storage_account_name
    input_container_name  = var.input_container_name
    output_container_name = var.output_container_name
    cu_endpoint           = "https://${var.foundry_account_name}.services.ai.azure.com/"
    di_endpoint           = "https://${var.foundry_account_name}.cognitiveservices.azure.com/"
    openai_endpoint       = "https://${var.foundry_account_name}.openai.azure.com/"
    search_endpoint       = "https://${var.search_service_name}.search.windows.net"
  }
}
