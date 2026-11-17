terraform {
  required_version = ">= 1.10.0"
  backend "azurerm" {}
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

provider "databricks" {
  host                        = var.workspace_url
  azure_workspace_resource_id = var.workspace_resource_id
  azure_tenant_id             = var.tenant_id
  auth_type                   = "azure-cli"
}

data "databricks_current_user" "instructor" {}

resource "databricks_service_principal" "notebooks" {
  application_id   = var.notebook_client_id
  display_name     = "rag-workshop-notebooks"
  workspace_access = true
}

resource "databricks_access_control_rule_set" "notebook_run_as" {
  name = "accounts/${var.databricks_account_id}/servicePrincipals/${databricks_service_principal.notebooks.application_id}/ruleSets/default"

  grant_rules {
    principals = ["users/${data.databricks_current_user.instructor.user_name}"]
    role       = "roles/servicePrincipal.manager"
  }
  grant_rules {
    principals = ["users/${data.databricks_current_user.instructor.user_name}"]
    role       = "roles/servicePrincipal.user"
  }
}

resource "databricks_secret_scope" "notebooks" {
  name = "rag-workshop"
}

resource "databricks_secret_acl" "notebooks" {
  scope      = databricks_secret_scope.notebooks.name
  principal  = databricks_service_principal.notebooks.application_id
  permission = "READ"
}

resource "databricks_cluster" "workshop" {
  cluster_name            = "rag-workshop-classic"
  spark_version           = var.runtime_version
  node_type_id            = var.node_type_id
  driver_node_type_id     = var.node_type_id
  num_workers             = 1
  data_security_mode      = "USER_ISOLATION"
  runtime_engine          = "STANDARD"
  autotermination_minutes = 20
  spark_env_vars          = var.notebook_environment
  custom_tags = {
    project         = "rag-workshop"
    SecurityControl = "Ignore"
  }
  azure_attributes {
    availability = "ON_DEMAND_AZURE"
  }
}

resource "databricks_permissions" "compute" {
  cluster_id = databricks_cluster.workshop.id
  access_control {
    user_name        = data.databricks_current_user.instructor.user_name
    permission_level = "CAN_MANAGE"
  }
  access_control {
    service_principal_name = databricks_service_principal.notebooks.application_id
    permission_level       = "CAN_ATTACH_TO"
  }
}

resource "databricks_repo" "instructor" {
  url    = var.repository_url
  branch = "main"
  path   = "${data.databricks_current_user.instructor.home}/azure-rag-workshop"
}

locals {
  flows = {
    cu = "01_cu_extraction_step_by_step.ipynb"
    di = "01_di_extraction_step_by_step.ipynb"
  }
}

resource "databricks_job" "workshop" {
  for_each            = local.flows
  name                = "rag-workshop-${each.key}"
  max_concurrent_runs = 1
  timeout_seconds     = 3600
  tags = {
    project         = "rag-workshop"
    SecurityControl = "Ignore"
  }

  git_source {
    url      = var.repository_url
    provider = "gitHub"
    commit   = var.repository_commit
  }
  run_as {
    service_principal_name = databricks_service_principal.notebooks.application_id
  }
  parameter {
    name    = "CLAIM_FOLDER"
    default = var.default_claim_folder
  }
  task {
    task_key            = "extract"
    existing_cluster_id = databricks_cluster.workshop.id
    max_retries         = 0
    timeout_seconds     = 2700
    notebook_task {
      notebook_path = "demo/rag/notebooks/databricks-runtime/${each.key}/${each.value}"
      source        = "GIT"
      base_parameters = {
        CLAIM_FOLDER = "{{job.parameters.CLAIM_FOLDER}}"
      }
    }
  }
  task {
    task_key            = "load"
    existing_cluster_id = databricks_cluster.workshop.id
    max_retries         = 0
    timeout_seconds     = 900
    depends_on {
      task_key = "extract"
    }
    notebook_task {
      notebook_path = "demo/rag/notebooks/databricks-runtime/${each.key}/03_populate_index.ipynb"
      source        = "GIT"
      base_parameters = {
        CLAIM_FOLDER = "{{job.parameters.CLAIM_FOLDER}}"
      }
    }
  }
  depends_on = [
    databricks_secret_acl.notebooks,
    databricks_permissions.compute,
    databricks_access_control_rule_set.notebook_run_as,
  ]
}

resource "databricks_permissions" "jobs" {
  for_each = local.flows
  job_id   = databricks_job.workshop[each.key].id
  access_control {
    user_name        = data.databricks_current_user.instructor.user_name
    permission_level = "IS_OWNER"
  }
  access_control {
    service_principal_name = databricks_service_principal.notebooks.application_id
    permission_level       = "CAN_MANAGE_RUN"
  }
}
