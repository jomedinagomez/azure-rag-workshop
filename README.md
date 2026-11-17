# Azure RAG workshop

Bring your own cleared files and existing Azure services. Run the same Python
notebooks locally or in Azure Databricks:

**Files and email attachments -> extraction -> Markdown chunks -> embeddings ->
Azure AI Search -> semantic hybrid retrieval.**

Adapted from the self-contained [insurance RAG notebooks](https://github.com/jomedinagomez/azure-ai-foundry-insurance/tree/main/demo/rag).
The Markdown/DataFrame workflow, MSG parsing and deduplication, contextual
embedding inputs, 18-field evidence schema, deterministic IDs,
and push-based loading are retained. The workshop adds Document Intelligence,
portable storage paths, and Databricks authentication. There is no app, agent,
Spark rewrite, or dependency on the original repository. Cells call Python and
the SDKs directly: no kernel gate, notebook self-test, configuration framework,
or schema-validation layer. Exceptions are not caught and rewritten.

## Notebook environments

Choose the runtime first, then the extraction flow. Start with **Content
Understanding** as the reference and compare the separate DI + GPT-5 workflow.

| Environment | Content Understanding | Document Intelligence + GPT-5 |
|---|---|---|
| Non-spark: standard Python/Jupyter, local `.venv` and `.env` | [CU notebooks](demo/rag/notebooks/non-spark/cu/) | [DI notebooks](demo/rag/notebooks/non-spark/di/) |
| Databricks Runtime: notebook packages, secret scope, Volumes/ADLS | [CU notebooks](demo/rag/notebooks/databricks-runtime/cu/) | [DI notebooks](demo/rag/notebooks/databricks-runtime/di/) |

```text
demo/rag/notebooks/
  non-spark/
    cu/
    di/
  databricks-runtime/
    cu/
    di/
```

Each of the four folders has the same three steps: `01_*_extraction_step_by_step`,
`02_create_index`, and `03_populate_index`. The processing cells are the same;
the setup cells explicitly match their environment. There is no runtime detection,
extraction-provider switch, or shared Python helper file.

The Databricks version uses Python/pandas on the driver, not distributed Spark
transformations. This separation is about the execution environment, not a
different RAG algorithm.

### CU is the visual-evidence reference

- PDFs, including embedded photos/diagrams, use native `prebuilt-documentSearch`.
- Document scans and data-rich chart/diagram images also use documentSearch.
  The visible `document_image_names` set selects those images; edit it for
  your inputs. Finding a character with OCR is not image classification.
- Photos use native `prebuilt-imageSearch`, including photos with annotations.
- Keep document Markdown, image summaries, and separately citable figure rows.
  Figure rows retain native descriptions and any returned chart/diagram
  content, not a rewritten summary. PDF crops are not separately resubmitted.
- Parse nested MSGs locally. Repeated email bodies do not prevent visiting
  their attachments; exact duplicate document bytes share one analysis.

### DI + GPT-5 mirrors the visual-evidence workflow

The separate DI notebook makes the extra visual step explicit:

1. Use native `prebuilt-layout` for OCR, tables, structure, and PDF figures.
2. Download PDF figure crops with DI's native API and preserve their figure
   IDs and page regions. No custom PDF rendering or crop-coordinate math.
3. Use an existing GPT-5 vision deployment for full standalone visual images
   and those PDF figure crops. Describe readable text, chart values/units, and
   diagram relationships as well as visible conditions.
4. Keep OCR text and GPT descriptions as separate evidence rows, then use the
   same chunking, embeddings, index schema, and retrieval sequence as CU.

The visible `document_image_names` set selects plain document-scan images
that need OCR only. It defaults to the demo's `site-access.png`; photos and
charts still receive visual analysis even if OCR found text. Edit the set
for your inputs rather than treating OCR presence as image classification.

Set `AZURE_OPENAI_VISION_DEPLOYMENT` to an approved existing GPT-5 deployment.
The local walkthrough uses `gpt-5.2`; no model is deployed by the notebooks.
Calls use the same OpenAI endpoint and Entra credential as embeddings. CU is
never called from the DI notebooks, and native DI output is not presented as
if it included visual interpretation.

Full GPT responses, descriptions, and DI crops are saved for inspection and
reuse. Compare coverage with CU on representative evidence; matching the
workflow does not guarantee identical descriptions or accuracy. Only figures
detected by DI receive crops, so review their coverage against the PDF. Neither
service's visual description is a finding of cause, timing, liability, or coverage.

CU uses `CU_OUTPUT_ROOT` and `AZURE_SEARCH_CU_INDEX_NAME`; DI uses
`DI_OUTPUT_ROOT` and `AZURE_SEARCH_DI_INDEX_NAME`. Outputs and indexes never
depend on a service-selection flag. The index-creation cell runs once for a
new name; an existing index produces the SDK's error, not an overwrite.

Supported inputs match the source walkthrough: PDF, JPG/JPEG, PNG, and Outlook
MSG with nested MSG/PDF/image attachments. Unsupported loose files are reported
in the preview; unsupported attachments stop at the parser. Convert these
formats deliberately before continuing. Arbitrary customer
filenames are supported; there is no fixture-specific signature exclusion.
This is a small, driver-side teaching pipeline, not a distributed ingestion job.

See the [walkthrough](demo/rag/README.md) for outputs and the 90-minute agenda.

## Existing-service prerequisites

- An approved CU-enabled Foundry account for the CU notebooks, or an approved
  Document Intelligence-capable resource for the DI notebooks.
- An Azure OpenAI embedding deployment. Its endpoint is configured separately
  from DI/CU; no CU resource is required for the DI route.
- An approved GPT-5 vision deployment in that OpenAI account for the DI visual
  step, configured with `AZURE_OPENAI_VISION_DEPLOYMENT`.
- Azure AI Search with semantic ranker enabled and capacity for the configured
  vector dimensions. Use a unique index name per participant.
- Network/DNS access from the executing computer or Databricks compute to DI,
  OpenAI, Search, and storage. Push indexing does not require a Search indexer
  or a Search-to-storage connection.
- Microsoft Entra permissions for the identity actually making Azure calls:
  the appropriate Cognitive Services analysis role on DI/CU, Cognitive Services
  OpenAI User on the embedding resource, Search Service Contributor for index
  creation, and Search Index Data Contributor for upload/query.
- For direct ADLS: Storage Blob Data Reader on inputs and Storage Blob Data
  Contributor on outputs, plus applicable directory ACLs.

Administrators should scope permissions to the selected resources and use the
organization's approved roles. RBAC is separate from network access. No API-key
fallback, Azure role assignment, or resource provisioning runs from the notebooks.

## Run locally first: non-spark

Open this repository as a VS Code folder. Use Python 3.12 and this repository's
own `.venv`, not a same-named environment from another project. Run commands in
a visible VS Code PowerShell terminal:

```powershell
uv venv --python 3.12 .venv
uv pip install --python .venv\Scripts\python.exe -r requirements.txt
Copy-Item .env.example .env
az login --tenant <your-tenant>
az account set --subscription <your-subscription>
```

If `uv` encounters a corporate-network TLS handshake failure, keep certificate
verification enabled and use the system Python's pip to target the same `.venv`:

```powershell
py -3.12 -m pip --python .venv\Scripts\python.exe install -r requirements.txt
```

Fill in the non-secret endpoints, embedding deployment, input/output locations,
and separate CU/DI index names in `.env`. Place cleared files under
`data\claims\<claim-id>` or configure another folder. Select `.venv` as the
notebook kernel and work through the notebooks interactively.
Open [non-spark CU](demo/rag/notebooks/non-spark/cu/) or
[non-spark DI](demo/rag/notebooks/non-spark/di/); these notebooks contain no
`dbutils` calls or Databricks setup.

All notebooks use `DefaultAzureCredential`. Optionally set
`AZURE_TOKEN_CREDENTIALS=AzureCliCredential` to select the signed-in CLI identity.
For local service-principal runs, provide `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`,
and `AZURE_CLIENT_SECRET` in the ignored local environment; the SDK reads them
automatically. Never put credentials in notebook cells.

Paid extraction, vision, embedding calls, and Search writes are separate, clearly labelled
cells; do not use **Run All** before reviewing them. Missing settings, bad paths,
authentication failures, and service errors surface at the operation that uses
them. The few explicit errors handle parser limitations, empty extracted
CU evidence, and Search batch failures that are returned as results rather than
thrown by the SDK.

## Run the workshop in Databricks

1. Add this repository as a **Databricks Git folder**. Use Python compute with
   Python 3.12 and Unity Catalog Volumes support (Databricks Runtime 16.4 LTS or
   a compatible newer runtime). A workspace alone does not provide compute,
   metastore assignment, a catalog, or a volume.
2. Open [Databricks Runtime CU](demo/rag/notebooks/databricks-runtime/cu/) or
   [Databricks Runtime DI](demo/rag/notebooks/databricks-runtime/di/).
   Each notebook starts with an executable package-install/restart cell using
   the root [requirements.txt](requirements.txt). Run that cell once, then
   continue after Python restarts. These notebooks do not read `.env`.

   Package installation needs approved package-repository access. The first
   token-counting run also downloads tiktoken's `cl100k_base` encoding unless
   it is already cached; prepare that cache if compute has restricted egress.

3. Have an administrator create an approved workspace secret scope and grant
   participants only the access they need. The default scope is `rag-workshop`;
   use these keys: `azure-tenant-id`, `azure-client-id`, `azure-client-secret`.
   Secrets belong to an existing Entra service principal with the Azure
   permissions above, not to the repository.
4. Configure the nonsecret cluster environment variables, or edit the existing
   **configuration cell** in each notebook: endpoints, output paths, deployment
   names, dimensions, and secret-scope name. Cluster-supplied values are preserved.
   Match settings across the three notebooks. Notebooks 1 and 3 expose one
   `CLAIM_FOLDER` widget, also used by Jobs to select a claim.
   The bootstrap cell reads the service principal from the secret
   scope into the Azure environment variables for `DefaultAzureCredential`.
   Credentials are not stored in the notebook.
   The Databricks examples use distinct `claims-cu-databricks-v1` and
   `claims-di-databricks-v1` indexes, avoiding the local rehearsal indexes.
5. Run the same cells used locally. No Azure CLI login, PAT, storage account
   key, DBFS mount, or Spark OAuth configuration is required for this code.

### Option A: Unity Catalog Volumes

Use existing, approved volumes:

```text
CLAIM_FOLDER=/Volumes/<catalog>/<schema>/<volume>/claims/<claim-id>
CU_OUTPUT_ROOT=/Volumes/<catalog>/<schema>/<volume>/rag-output/cu
DI_OUTPUT_ROOT=/Volumes/<catalog>/<schema>/<volume>/rag-output/di
```

The notebooks use ordinary Python file access. The Databricks **run identity**
needs `USE CATALOG`, `USE SCHEMA`, `READ VOLUME` on inputs, and `WRITE VOLUME`
on outputs. These grants are distinct from the service principal used by the
notebook to call Azure AI services.

### Option B: direct ADLS Gen2

```text
CLAIM_FOLDER=abfss://<filesystem>@<account>.dfs.core.windows.net/claims/<claim-id>
CU_OUTPUT_ROOT=abfss://<filesystem>@<account>.dfs.core.windows.net/rag-output/cu
DI_OUTPUT_ROOT=abfss://<filesystem>@<account>.dfs.core.windows.net/rag-output/di
```

The Azure Data Lake SDK uses the selected Entra credential, not Spark/DBFS.
Input files and prior output caches are staged to a temporary driver folder.
Raw extraction results, attachments, native text, prepared records, and upload
reports are persisted back to ADLS as they are saved. Indexed provenance keeps
the ADLS URI, not a temporary driver path. Missing containers, access failures,
or upload failures surface as errors. Existing filesystems must already exist.
Temporary staging is removed by each notebook's cleanup cell; durable data
is not removed.

You can mix ADLS inputs with Volume outputs, or vice versa. Direct ADLS also
works locally with `DefaultAzureCredential`. Keep inputs and outputs separate.

## Infrastructure and scope

Reuse your existing Foundry/OpenAI, DI, Search, storage, and observability.
The [deployment guide](infra/README.md) separates three Terraform stages:
existing-storage bootstrap, a public Azure Databricks workspace and scoped
Entra identity, then Classic compute, secret-scope permissions, a public Git
folder, and CU/DI jobs. It reuses existing AI services and ADLS rather than
recreating them. Public endpoints still require authentication; containers
are not anonymously readable. No GitHub read credential or PAT is required.

The recurring jobs run notebook **1 -> 3**, pinned to a reviewed public commit;
run notebook 2 once per new index. You can trigger and inspect them from your
computer while execution stays inside Databricks. Participants with existing
workspace/compute/identity/storage should follow the notebook instructions
above rather than deploy the instructor's rehearsal infrastructure.

This workshop stops at retrieval. Native Foundry agents, Genie MCP, structured
claims data, and a web client are later architecture stages, not prerequisites
for this ingestion session.

When changing embedding resources, use a new output root and index for the
comparison. CU and DI already have separate roots and indexes. The notebooks do not compare manifests or
inspect an existing index's schema before uploading.
Use distinct index names and output locations for separate runtime rehearsals
too; switching environments must not unintentionally synchronize another run.

Customer files, outputs, credentials, and Terraform state are ignored by Git.
Notebook previews show at most five rows, short text, and vector dimensions.
Before sharing, clear any outputs generated while working with private data.
The copied local demo packets are fictional and remain Git-ignored. Stage your
cleared files in a Volume or ADLS for Databricks; they are not published with Git.

## References

- [CU native prebuilt analyzers](https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/prebuilt-analyzers)
- [Vision-enabled models](https://learn.microsoft.com/azure/foundry/openai/how-to/gpt-with-vision)
- [Document Intelligence Python SDK](https://learn.microsoft.com/python/api/overview/azure/ai-documentintelligence-readme?view=azure-python)
- [Databricks secret management](https://learn.microsoft.com/azure/databricks/security/secrets/)
- [Files in Unity Catalog Volumes](https://learn.microsoft.com/azure/databricks/volumes/volume-files)
