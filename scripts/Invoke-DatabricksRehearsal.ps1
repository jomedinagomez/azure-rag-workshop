param(
    [string]$AzureConfiguration = "$PSScriptRoot\..\output\deployment\azure-configuration.json",
    [string]$WorkspaceConfiguration = "$PSScriptRoot\..\output\deployment\databricks-configuration.json",
    [string]$ReportDirectory = "$PSScriptRoot\..\output\deployment\runs",
    [ValidateRange(1, 30)][int]$SecretLifetimeDays = 7
)

$ErrorActionPreference = 'Stop'
$azure = Get-Content -LiteralPath $AzureConfiguration -Raw | ConvertFrom-Json
$workspace = Get-Content -LiteralPath $WorkspaceConfiguration -Raw | ConvertFrom-Json
$hostUrl = $workspace.workspace_url.TrimEnd('/')
$databricksResource = '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
$tokens = @{}
$clientSecret = $null
$runs = [System.Collections.Generic.List[object]]::new()
$jobSettings = @{}
New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null

function Get-WorkspaceToken {
    param([ValidateSet('User', 'Principal')][string]$Caller)
    if ($tokens.ContainsKey($Caller) -and $tokens[$Caller].Expires -gt [DateTimeOffset]::UtcNow.AddMinutes(5)) {
        return $tokens[$Caller].Value
    }
    if ($Caller -eq 'User') {
        $raw = az account get-access-token --resource $databricksResource -o json
        if ($LASTEXITCODE -ne 0) { throw 'Could not obtain the instructor Databricks token.' }
        $token = $raw | ConvertFrom-Json
        $tokens[$Caller] = @{
            Value = $token.accessToken
            Expires = [DateTimeOffset]::FromUnixTimeSeconds([long]$token.expires_on)
        }
    } else {
        $token = Invoke-RestMethod -Method Post `
            -Uri ("https://login.microsoftonline.com/" + $azure.tenant_id + "/oauth2/v2.0/token") `
            -ContentType 'application/x-www-form-urlencoded' -Body @{
                client_id = $azure.notebook_client_id
                client_secret = $clientSecret
                grant_type = 'client_credentials'
                scope = "$databricksResource/.default"
            }
        $tokens[$Caller] = @{
            Value = $token.access_token
            Expires = [DateTimeOffset]::UtcNow.AddSeconds([int]$token.expires_in)
        }
    }
    return $tokens[$Caller].Value
}

function Invoke-WorkspaceApi {
    param(
        [string]$Path,
        [ValidateSet('GET', 'POST')][string]$Method = 'GET',
        [ValidateSet('User', 'Principal')][string]$Caller = 'User',
        [hashtable]$Body
    )
    $request = @{
        Uri = $hostUrl + $Path
        Method = $Method
        Headers = @{ Authorization = 'Bearer ' + (Get-WorkspaceToken $Caller) }
        TimeoutSec = 60
    }
    if ($Method -eq 'POST') {
        $request.ContentType = 'application/json'
        $request.Body = $Body | ConvertTo-Json -Depth 20 -Compress
    }
    Invoke-RestMethod @request
}

function Wait-NotebookRun {
    param([long]$RunId, [string]$Caller, [string]$Label)
    $deadline = [DateTimeOffset]::UtcNow.AddMinutes(70)
    $lastState = ''
    do {
        $run = Invoke-WorkspaceApi -Caller $Caller -Path ("/api/2.2/jobs/runs/get?run_id=" + $RunId)
        $state = $run.state.life_cycle_state
        if ($state -ne $lastState) {
            Write-Host "$Label : $state"
            $lastState = $state
        }
        if ($state -in @('TERMINATED', 'SKIPPED', 'INTERNAL_ERROR')) {
            $run | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $ReportDirectory "$RunId.json") -Encoding utf8
            if ($run.state.result_state -ne 'SUCCESS') {
                foreach ($task in $run.tasks | Where-Object { $_.state.result_state -eq 'FAILED' }) {
                    $failure = Invoke-WorkspaceApi -Caller $Caller -Path ("/api/2.2/jobs/runs/get-output?run_id=" + $task.run_id)
                    Write-Host $failure.error
                    Write-Host $failure.error_trace
                }
                throw "$Label failed: $($run.state.state_message). Run: $($run.run_page_url)"
            }
            if (@($run.tasks | Where-Object { $_.state.result_state -ne 'SUCCESS' }).Count -gt 0) {
                throw "$Label has a task that did not succeed."
            }
            return $run
        }
        Start-Sleep -Seconds 15
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "$Label did not complete before the polling deadline. Inspect run $RunId before retrying."
}

try {
    foreach ($flow in @('cu', 'di')) {
        $job = Invoke-WorkspaceApi -Path ("/api/2.2/jobs/get?job_id=" + $workspace.job_ids.$flow)
        if ($job.settings.run_as.service_principal_name -ne $azure.notebook_client_id) {
            throw "$flow job does not have the expected service-principal Run as identity."
        }
        $jobSettings[$flow] = $job.settings
    }
    $graphRaw = az account get-access-token --resource 'https://graph.microsoft.com' -o json
    if ($LASTEXITCODE -ne 0) { throw 'Could not obtain the application-owner Graph token.' }
    $graph = $graphRaw | ConvertFrom-Json
    $password = Invoke-RestMethod -Method Post `
        -Uri ("https://graph.microsoft.com/v1.0/applications/" + $azure.application_object_id + "/addPassword") `
        -Headers @{ Authorization = 'Bearer ' + $graph.accessToken } `
        -ContentType 'application/json' -Body (@{
            passwordCredential = @{
                displayName = 'rag-workshop-notebooks'
                endDateTime = [DateTimeOffset]::UtcNow.AddDays($SecretLifetimeDays).ToString('o')
            }
        } | ConvertTo-Json -Compress)
    $clientSecret = $password.secretText
    if (-not $clientSecret) { throw 'Graph did not return the new credential.' }
    $values = @{
        'azure-tenant-id' = $azure.tenant_id
        'azure-client-id' = $azure.notebook_client_id
        'azure-client-secret' = $clientSecret
    }
    foreach ($key in $values.Keys) {
        Invoke-WorkspaceApi -Method POST -Path '/api/2.0/secrets/put' -Body @{
            scope = $workspace.secret_scope
            key = $key
            string_value = $values[$key]
        } | Out-Null
    }
    @{
        client_id = $azure.notebook_client_id
        key_id = $password.keyId
        expires = $password.endDateTime
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ReportDirectory 'credential-metadata.json') -Encoding utf8
    Write-Host 'Short-lived credential stored in the Databricks scope; its value was not written to disk or displayed.'
    $values.Clear()
    $password = $null
    $graph = $null
    $graphRaw = $null

    foreach ($caller in @('User', 'Principal')) {
        $claim = if ($caller -eq 'User') { 'claim-001' } else { 'claim-003' }
        foreach ($flow in @('cu', 'di')) {
            $started = Invoke-WorkspaceApi -Caller $caller -Method POST -Path '/api/2.2/jobs/run-now' -Body @{
                job_id = [long]$workspace.job_ids.$flow
                job_parameters = @{
                    CLAIM_FOLDER = "abfss://$($azure.input_container_name)@$($azure.storage_account_name).dfs.core.windows.net/claims/$claim"
                }
            }
            $completed = Wait-NotebookRun -RunId $started.run_id -Caller $caller -Label "$flow / $claim / $caller"
            $runs.Add(@{
                flow = $flow
                claim = $claim
                caller = $caller
                run_id = $completed.run_id
                run_as = $jobSettings[$flow].run_as.service_principal_name
                result = $completed.state.result_state
                run_url = $completed.run_page_url
                git_source = $completed.tasks[0].git_source
            })
            $runs.ToArray() | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $ReportDirectory 'rehearsal-runs.json') -Encoding utf8
            Write-Host $completed.run_page_url
        }
    }
} finally {
    $clientSecret = $null
    $password = $null
    $tokens.Clear()
    if ($values) { $values.Clear() }
}
