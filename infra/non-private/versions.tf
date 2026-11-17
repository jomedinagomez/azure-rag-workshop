terraform {
  required_version = ">= 1.10.0"
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.57.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.8.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}
