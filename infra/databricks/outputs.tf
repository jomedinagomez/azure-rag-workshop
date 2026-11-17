output "configuration" {
  value = {
    workspace_url        = var.workspace_url
    cluster_id           = databricks_cluster.workshop.id
    secret_scope         = databricks_secret_scope.notebooks.name
    notebook_client_id   = var.notebook_client_id
    job_ids              = { for flow, job in databricks_job.workshop : flow => job.id }
    repository_url       = var.repository_url
    repository_commit    = var.repository_commit
    instructor_repo_path = databricks_repo.instructor.path
    default_claim_folder = var.default_claim_folder
  }
}
