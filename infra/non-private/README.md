# Azure workspace and identity stage

This Terraform root adds a public Premium Azure Databricks workspace and a
dedicated Entra application/service principal to an existing resource group.
It reads existing Foundry, Search, and ADLS resource metadata without importing
those resources or retrieving their account keys.

It also creates private input/output containers and narrowly scoped roles:

- Cognitive Services User and Cognitive Services OpenAI User on Foundry.
- Search Index Data Contributor on Search.
- Storage Blob Data Reader on the input container.
- Storage Blob Data Contributor on the output container.
- Optional setup-only Search Service Contributor for creating the indexes.

After both indexes exist, set `enable_index_setup_role = false`, review the
plan, and apply the removal of that role assignment only. Retain the ongoing
data-plane permissions.

The workspace UI/API is public. Compute requests no public node IPs; that
does not make the workspace private. No private endpoints, private DNS,
enterprise VNet injection, or anonymous storage access are configured.
`SecurityControl=Ignore` is applied to the workspace.

This root does not create client-secret values, compute, notebooks, or jobs.
Those are separate steps. Workspace and input/output container destruction
are protected. Do not copy the original application's state into this root.

See the [three-stage deployment guide](../README.md) for backend setup,
validation, workspace configuration, and native rehearsals.
