variable "workspace_url" {
  type = string
}

variable "workspace_resource_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "notebook_client_id" {
  type = string
}

variable "runtime_version" {
  description = "Python 3.12 LTS runtime ID verified from this workspace's spark-versions API."
  type        = string
}

variable "node_type_id" {
  type    = string
  default = "Standard_D4ds_v5"
}

variable "notebook_environment" {
  description = "Nonsecret endpoints, deployment names and ADLS roots only. Never put credentials here."
  type        = map(string)
}

variable "repository_url" {
  type    = string
  default = "https://github.com/jomedinagomez/azure-rag-workshop.git"
}

variable "repository_commit" {
  description = "Reviewed public Git commit used by both tasks in each job."
  type        = string
}

variable "default_claim_folder" {
  type = string
}
