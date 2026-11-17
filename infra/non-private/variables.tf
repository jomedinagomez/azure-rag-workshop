variable "subscription_id" {
  description = "Subscription containing the existing rehearsal resource group."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group. This stack does not create or manage it."
  type        = string
}

variable "workspace_name" {
  description = "Name of the new Azure Databricks workspace."
  type        = string
  default     = "dbw-rag-workshop-dev-01"
}

variable "storage_account_name" {
  description = "Existing ADLS Gen2 account; never recreated by this root."
  type        = string
}

variable "foundry_account_name" {
  description = "Existing account providing CU, DI, vision, and embeddings."
  type        = string
}

variable "search_service_name" {
  description = "Existing Azure AI Search service."
  type        = string
}

variable "principal_name" {
  type    = string
  default = "sp-rag-workshop-dev-01"
}

variable "input_container_name" {
  type    = string
  default = "rag-workshop-input"
}

variable "output_container_name" {
  type    = string
  default = "rag-workshop-output"
}

variable "enable_index_setup_role" {
  description = "Temporarily permit the notebook principal to create the two rehearsal indexes."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for the Databricks workspace."
  type        = map(string)
  default = {
    project         = "rag-workshop"
    environment     = "dev"
    managed_by      = "terraform"
    SecurityControl = "Ignore"
  }
}
