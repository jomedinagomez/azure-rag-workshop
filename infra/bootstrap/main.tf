terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.8.0"
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "state_container_name" {
  type    = string
  default = "rag-workshop-tfstate"
}

data "azapi_resource" "existing_storage" {
  type                   = "Microsoft.Storage/storageAccounts@2023-05-01"
  resource_id            = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name}"
  response_export_values = ["tags"]
}

resource "azapi_update_resource" "storage_public_access" {
  type        = "Microsoft.Storage/storageAccounts@2023-05-01"
  resource_id = data.azapi_resource.existing_storage.id
  body = {
    tags = merge(data.azapi_resource.existing_storage.output.tags, {
      SecurityControl = "Ignore"
    })
    properties = {
      publicNetworkAccess = "Enabled"
    }
  }
}

resource "azapi_resource" "state_container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = var.state_container_name
  parent_id = "${data.azapi_resource.existing_storage.id}/blobServices/default"
  body = {
    properties = {
      publicAccess = "None"
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}
