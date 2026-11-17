# Guided RAG walkthrough

Choose an environment, then use its three CU notebooks as the reference and
its separate DI notebooks for the matching DI + GPT-5 workflow.

| Environment | CU | DI + GPT-5 |
|---|---|---|
| Standard Python / non-spark | [CU](notebooks/non-spark/cu/) | [DI](notebooks/non-spark/di/) |
| Databricks Runtime | [CU](notebooks/databricks-runtime/cu/) | [DI](notebooks/databricks-runtime/di/) |

Non-spark notebooks use the root `.venv` and `.env` with no Databricks code.
Databricks Runtime notebooks have their own package-install, configuration,
and secret-scope setup cells; they do not load `.env` or detect a runtime.
Processing remains Python/pandas on the driver, not distributed Spark.
Each notebook is self-contained: no app imports, service-selection switches,
or helper runner.
Configure the environment as described in the [repository guide](../../README.md).

## Suggested 90-minute session

| Minutes | Exercise |
|---|---|
| 0-15 | Confirm paths, identity, network access, and a few cleared source files. |
| 15-40 | Notebook 1: inspect files and emails, review image roles, call CU, review native text and visual evidence. |
| 40-60 | Continue notebook 1: chunk, count tokens, embed, review and save full records. |
| 60-70 | Notebook 2: inspect the schema, vector profile, and semantic configuration; create the index. |
| 70-85 | Notebook 3: upload, inspect indexed rows, and run a semantic hybrid query. |
| 85-90 | Compare CU's native visual analysis with DI's explicit GPT-5 visual stage. |

Install libraries, grant permissions, and confirm approved service endpoints
before the session. A few representative files are sufficient.

## CU process

1. Select one claim and preview its files.
2. Read MSG bodies and attachments recursively. Always visit attachments,
   even when message headers/body match a previous occurrence.
3. Deduplicate document bytes and review the analyzer routes.
4. Call native CU and retain the complete response.
5. Inspect document Markdown, photo summaries, and native figure content.
6. Split Markdown; keep image summaries and figures as separate evidence rows.
7. Review contextual embedding inputs and token counts; generate one vector per row.
8. Save complete records; create the CU index; upload and run semantic hybrid search.

| Evidence | Native analyzer |
|---|---|
| PDF, including embedded photos/charts/diagrams | `prebuilt-documentSearch` |
| Document-scan image or data-rich chart/diagram image | `prebuilt-documentSearch` |
| Photo, including an annotated photo | `prebuilt-imageSearch` |

The routing cell's `document_image_names` explicitly selects document-like
images. It includes the demo's `survey-chart.png` and `site-access.png`.
Change it for your files. This is not a claim that filenames or OCR characters
automatically identify an image's purpose. No separate PDF crop calls occur.

For figures, retain both native `description` and `content` when returned.
Structured chart/diagram content is saved and indexed alongside its description.
Do not reduce a chart to a vague summary or treat visual observations as findings
of causation or coverage.

## Matching DI + GPT-5 process

The DI notebook keeps `prebuilt-layout` for native Markdown, tables, and figure
metadata, then explicitly adds the visual-analysis work that CU supplies natively:

- Plain document-scan images listed in `document_image_names` use OCR/layout.
- Other standalone images, including photos with labels and charts, go to GPT
  as full images. Their OCR text is retained separately.
- PDFs request `output=['figures']`. Native DI crops are downloaded immediately
  and sent to GPT with any detected caption/footnotes as labelled source context.
- The visual prompt asks for readable labels, exact values/units, diagram
  relationships, and uncertainties, without inferring causation or coverage.
- GPT image/figure descriptions become separate evidence rows before embedding.
  PDF rows retain the original PDF path, native figure ID, and page regions.

`AZURE_OPENAI_VISION_DEPLOYMENT=gpt-5.2` selects the existing deployment for the
local walkthrough. Use an approved GPT-5 vision deployment in your own account.
No new resources or CU calls are added to this path. Refusals, incomplete visual
responses, and service errors stop instead of turning into empty evidence.

## Saved artifacts

Outputs and indexes are separate without a provider flag:

| Flow | Output root | Default index |
|---|---|---|
| CU | `CU_OUTPUT_ROOT=output/claims/cu` | `claims-cu-v1` |
| DI | `DI_OUTPUT_ROOT=output/claims/di` | `claims-di-v1` |

Those defaults describe the non-spark notebooks. Databricks configuration
cells use Volume paths and distinct `claims-cu-databricks-v1` /
`claims-di-databricks-v1` indexes. Keep each runtime's input/output/index settings
consistent across its three notebooks. ADLS URIs work in either environment.
Cluster-supplied nonsecret settings are preserved. Databricks notebooks 1
and 3 expose a `CLAIM_FOLDER` widget for interactive selection or a Job
parameter. The [deployment guide](../../infra/README.md) defines separate
CU/DI jobs pinned to a public Git commit; every loop runs 1 -> 2 -> 3 and
starts with fresh outputs and index data.

```text
<CU_OUTPUT_ROOT>/<claim-id>/
  attachments/
  analysis-results/<resource-fingerprint>/
  <document-hash>_<content-number>.md
  <document-hash>_figure_<native-figure-id>.md
  processed-evidence-v1.json
  upload-results.json
```

DI uses the same artifact pattern under `DI_OUTPUT_ROOT`, adding:

```text
figures/<document-hash>_<native-figure-id>.png
vision-results/<openai-endpoint-fingerprint>/<deployment>_<request-hash>.json
<document-hash>_visual_<native-figure-id-or-image>.md
```

DI's native Markdown is still saved as `<document-hash>.md`. Vision request hashes
identify the image bytes, prompt, and caption context for the saved inspection
files; their folder and filename separate the endpoint and deployment.
PDF result filenames include `_figures`. These files are outputs, not caches:
the services are called again on every extraction run.

Each folder's notebook 3 reads its own `processed-evidence-v1.json` directly. Keep the same embedding
endpoint, deployment, and dimensions for ingestion and queries. Use a new index
and output root when changing those settings; there is no manifest validation.
Native-result filenames include analyzer, API version, and document hash.
The resource fingerprint organizes inspection outputs by endpoint; it does not
control whether a call is made.

The 18 evidence columns are retained from the source walkthrough:

`id`, `claim_id`, `document_hash`, `chunk_id`, `title`, `header`, `content`,
`source_type`, `content_kind`, `filename`, `source_path`, `source_files`,
`parent_emails`, `figure_id`, `source_region`, `analyzer_id`,
`analyzer_api_version`, `content_vector`.

Native CU figure IDs/regions are retained. In DI, OCR rows are `document_text`;
GPT outputs are `image_description` or `figure_description`. Their `analyzer_id`
combines `prebuilt-layout` with the GPT deployment, while `analyzer_api_version`
remains the DI API version. The full saved GPT response records its returned model
name. DI figure `source_region` stores the native page-number/polygon JSON.
No page field or visual finding is fabricated. A claim filter scopes retrieval,
not authorization.

## Teaching output and safe reruns

Previews show five rows, at most 160 characters per text value, and vector
dimensions only. One native Markdown excerpt is limited to 1,200 characters.
These limits do not truncate the DataFrames, saved content, vectors, or uploads.

Notebook 1 first clears only its generated output folder for the selected claim,
then repeats extraction, GPT visual analysis for DI, chunking, and embeddings.
Original input files are never deleted.

Notebook 2 deletes the configured demo index and recreates its schema on every
run. Notebook 3 also resets that index, then loads every prepared record from
notebook 1. This removes all previous index documents, including other claims.
There is no old-ID comparison, incremental synchronization, or stale-row phase.
Use dedicated demo indexes. Failed upload batches remain failures rather than
successful-looking output. Upload and query errors come directly
from the service rather than a separate schema-comparison layer.

The retrieval question is a separate editable cell. Rerunning it and the
following search cell makes one query-embedding call and one semantic hybrid
Search request, not another document-ingestion run. Semantic failures remain
errors rather than silently falling back to ordinary hybrid search.
