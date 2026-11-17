# Public Databricks rehearsal infrastructure

Participants clone this public repository as a Databricks Git folder and use
their own approved Classic compute, ADLS, Azure AI services, and identity.
Cloning code does not provision infrastructure or copy documents/credentials.
These Terraform roots build an optional, separate instructor rehearsal.

## What is deployed

| Root | Purpose |
|---|---|
| [bootstrap](bootstrap/) | Reuse an existing HNS-enabled account, enable its public endpoint, merge `SecurityControl=Ignore`, and create a private Terraform-state container |
| [non-private](non-private/) | Public Premium Databricks workspace, Entra app/SP, private input/output containers, scoped Azure permissions |
| [databricks](databricks/) | Workspace SP, secret scope/ACL, one Standard-mode Classic cluster, public Git folder, and CU/DI jobs |

Existing Foundry/OpenAI, DI, Search, models, and unrelated storage data are not
recreated. The workspace creates its required Azure-managed resource group
and service infrastructure. There are no private endpoints, private DNS,
VNet injection, or peering. Public access still requires Entra/Databricks
authentication; anonymous blob access must remain disabled.

The Classic cluster has one driver and one worker, CPU-only, on-demand nodes,
and 20-minute idle termination. Verify node availability and select a Python
3.12 LTS runtime using the actual workspace APIs. No schedule is configured.
`SecurityControl=Ignore` is set on the workspace and inherited by compute.
Do not duplicate inherited tag keys in cluster custom tags: Databricks renames
colliding keys, causing repeated Terraform differences.

## 1. Bootstrap state storage

Use a visible PowerShell terminal. Confirm subscription, region, account,
permissions, policy, quota, and cost before applying. Use cleared demo data
only. Terraform 1.10+, Azure CLI, and Databricks CLI are required.

```powershell
az login --tenant <tenant-id>
az account set --subscription <subscription-id>
Set-Location infra\bootstrap
Copy-Item terraform.tfvars-example terraform.tfvars
# Fill in the existing subscription, resource group and storage account.
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

The first bootstrap uses local, ignored state because the backend container
does not exist yet. After that apply:

```powershell
Copy-Item backend.tf-example backend.tf
Copy-Item backend.hcl-example backend.hcl
# Fill in the existing account and newly created private state container.
terraform init -migrate-state '-backend-config=backend.hcl'
```

Keep local state secure until migration succeeds. Backend access uses Entra,
not storage account keys. Never publish real backend configs, variable files,
state, plan files, credentials, or execution output.

## 2. Azure workspace and scoped identity

```powershell
Set-Location ..\non-private
Copy-Item terraform.tfvars-example terraform.tfvars
Copy-Item backend.hcl-example backend.hcl
# Use the existing services and a separate backend state key.
terraform init '-backend-config=backend.hcl'
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output -json configuration
```

The configuration output contains nonsecret IDs/endpoints, not a password.
Save it under the ignored `output\deployment\azure-configuration.json` if using
the rehearsal helper. An administrator needs application-registration access
and permission to assign the listed resource/container-scoped roles.

For the tenant's first workspace, use Azure's **Launch Workspace** and finish
any first-time account-name onboarding with the existing Entra sign-in.
This is not a separate free-trial or GitHub account. If establishing the first
tenant-wide account admin is required, an Entra Global Administrator must
perform that step; Azure subscription Owner does not grant that directory role.
See [Databricks administration](https://learn.microsoft.com/azure/databricks/admin/admin-concepts#establish-your-first-account-admin).

Workspace ARM `Succeeded` is not proof that its Databricks API is ready.
Before proceeding, set the following for the current terminal and verify:

```powershell
$env:DATABRICKS_HOST = 'https://<workspace-host>'
$env:DATABRICKS_AZURE_RESOURCE_ID = '<workspace-resource-id>'
$env:DATABRICKS_AUTH_TYPE = 'azure-cli'
$env:ARM_TENANT_ID = '<tenant-id>'
databricks current-user me
databricks clusters spark-versions
databricks clusters list-node-types
```

Fresh control-plane propagation can lag ARM completion. If the API remains
unavailable, diagnose the workspace; do not create credentials or claim that
compute/jobs are deployed. Do not delete/recreate resources as a workaround.

### If existing Azure automation resets storage settings

The public rehearsal needs the storage endpoint enabled as well as the
requested resource tag. Where the organization's policy explicitly supports
`SecurityControl=Ignore` and you are authorized to use it, restore just this
existing account with Azure CLI:

```powershell
$storageId = '<existing-storage-account-resource-id>'
az tag update --resource-id $storageId --operation Merge --tags SecurityControl=Ignore
az storage account update --ids $storageId --public-network-access Enabled
```

These commands preserve other tags/settings and do not enable anonymous
blobs, shared keys, or disable automation/policy. Verify the effective network
settings before resuming; automation can reset them again until its resource
configuration is updated. A reset also blocks Terraform's remote state when
that state uses the same account. Do not hide storage failures or switch to
account keys to get around them.

## 3. Databricks workspace configuration

Publish/review the public source first. Record its full commit hash, then:

```powershell
Set-Location ..\databricks
Copy-Item terraform.tfvars-example terraform.tfvars
Copy-Item backend.hcl-example backend.hcl
# Set actual workspace IDs, verified runtime, reviewed public commit,
# nonsecret model/endpoints/output roots, and the default ADLS claim folder.
# Set databricks_account_id from the Azure Databricks account console.
terraform init '-backend-config=backend.hcl'
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output -json configuration
```

Save that output under ignored
`output\deployment\databricks-configuration.json` for the helper. Only whitelist
nonsecret environment settings; do not copy the local `.env` wholesale or set
`AZURE_TOKEN_CREDENTIALS=AzureCliCredential` on compute.

The instructor can manage compute/jobs; the SP can attach to and restart this
existing cluster, read its secret scope, and trigger/manage runs.
`CAN_RESTART` is needed for saved jobs to start compute after auto-termination;
attach-only permission fails when the cluster is stopped.
Jobs have a fixed service-principal
**Run as** identity and are pinned to the reviewed Git commit. The Azure SP
used inside notebooks is the same dedicated identity. No GitHub credential
is created: the Git source is public.
The Azure-managed principal's display name is supplied by Entra synchronization,
not overwritten by the workspace template.

The instructor also needs Databricks **Service Principal User** on this
dedicated principal to set the jobs' Run as identity. Being its creator or
Service Principal Manager does not imply that permission. The rule-set
resource retains the creator's Manager role and adds User on this principal
only. This requires the Databricks account UUID, not an Azure directory or
subscription ID. Rule sets are authoritative: inspect existing grants before
applying if reusing a principal that other people already manage.

## 4. Data, secrets, and native rehearsals

Upload cleared input folders to the private input container:

```powershell
az storage blob upload-batch --account-name <account> `
  --destination rag-workshop-input --destination-path claims `
  --source data\claims --pattern 'claim-*/*' --auth-mode login --overwrite false
```

Preserve `claims/<claim-id>/...` folder structure. Verify uploaded file bytes,
not just file counts. Never upload real/customer data without clearance.

The notebooks read `azure-tenant-id`, `azure-client-id`, and
`azure-client-secret` from the `rag-workshop` scope. The
[rehearsal helper](../scripts/Invoke-DatabricksRehearsal.ps1) creates an additional
short-lived credential through Graph `addPassword`, seeds those values using
authenticated HTTPS request bodies, and keeps secret/token values in memory.
It does not reset existing credentials, put passwords in Terraform, or log
secret values. Review the script before using it:

```powershell
.\scripts\Invoke-DatabricksRehearsal.ps1
```

By default it runs notebook 2 once for each new CU/DI index, then the saved
CU/DI jobs for claim-001 as the instructor caller and claim-003 as the
principal caller. All saved jobs keep the same SP Run as identity.
The default credential expires in seven days; rotate it before later use.
Only nonsecret credential metadata and run reports are written under ignored
`output\deployment\runs`.

Index creation is intentionally not an upsert. If both indexes already exist
with the intended schema, use `-SkipIndexSetup`; do not delete existing
indexes to make setup pass. Remove the setup-only Search role after creation.
Recurring jobs run **notebook 1 -> notebook 3**, never notebook 2.

Native acceptance includes full durable ADLS outputs, 3072-dimensional vectors,
exact prepared/indexed ID equality per selected claim, visual/PDF provenance,
nested MSG attachments, and real semantic hybrid retrieval. Job success alone
does not establish those checks. Stop the owned cluster after verification.

## Trigger later from your computer

With the same Azure CLI/Databricks environment:

```powershell
databricks jobs run-now <cu-job-id>
databricks jobs run-now <di-job-id>
databricks jobs get-run <run-id>
databricks clusters delete <cluster-id>
```

`clusters delete` terminates the owned cluster; it does not delete the Azure
workspace or durable ADLS data. Your computer authorizes the trigger, while
notebook execution stays on Databricks Classic compute.
