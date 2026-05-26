# 04-prompt-init.ps1 -- One-shot Container Apps Job that registers prompts in MLflow.
#
# Uses the same backend image; overrides the command to run register_prompts.py.

. $PSScriptRoot\config.ps1

$acrServer = Get-EnvVar $EnvFile "ACR_LOGIN_SERVER"
$acrUser   = Get-EnvVar $EnvFile "ACR_USERNAME"
$acrPass   = Get-EnvVar $EnvFile "ACR_PASSWORD"
$mlflowUrl = Get-EnvVar $EnvFile "MLFLOW_TRACKING_URI"
foreach ($v in @("acrServer","acrUser","acrPass","mlflowUrl")) {
    if (-not (Get-Variable -Name $v -ValueOnly)) { throw "Missing .env value: $v -- run 01..03 first." }
}

$backendTag = "$acrServer/$BackendImage"

$jobExists = az containerapp job show --name $PromptInitJob --resource-group $ResourceGroup --query "name" -o tsv 2>$null
if (-not $jobExists) {
    Write-Host "[04] Creating Container Apps Job '$PromptInitJob' ..." -ForegroundColor Cyan
    az containerapp job create `
        --name $PromptInitJob `
        --resource-group $ResourceGroup `
        --environment $EnvName `
        --trigger-type Manual `
        --replica-timeout 600 `
        --replica-retry-limit 1 `
        --parallelism 1 `
        --replica-completion-count 1 `
        --image $backendTag `
        --cpu 0.5 --memory 1.0Gi `
        --registry-server $acrServer `
        --registry-username $acrUser `
        --registry-password $acrPass `
        --env-vars "MLFLOW_TRACKING_URI=$mlflowUrl" "GIT_PYTHON_REFRESH=quiet" `
        --command "uv" `
        --args "run" "python" "-m" "rag.prompt_engineering.register_prompts" `
        --only-show-errors --output none
} else {
    Write-Host "[04] Job exists, updating image + env ..." -ForegroundColor Yellow
    az containerapp job update `
        --name $PromptInitJob `
        --resource-group $ResourceGroup `
        --image $backendTag `
        --set-env-vars "MLFLOW_TRACKING_URI=$mlflowUrl" "GIT_PYTHON_REFRESH=quiet" `
        --only-show-errors --output none
}

# --- Run it -------------------------------------------------------------------
Write-Host "[04] Starting job ..." -ForegroundColor Cyan
$exec = az containerapp job start --name $PromptInitJob --resource-group $ResourceGroup -o json | ConvertFrom-Json
$execName = $exec.name
Write-Host "[04] Execution: $execName" -ForegroundColor DarkGray

# Wait up to ~10 minutes for the execution to finish.
# First cold-start run can take 4-7 min (replica schedule + image pull + python boot).
$timeoutSec = 600
$elapsed = 0
$status  = "Running"
while ($elapsed -lt $timeoutSec) {
    Start-Sleep -Seconds 10
    $elapsed += 10
    $status = az containerapp job execution show `
        --name $PromptInitJob `
        --resource-group $ResourceGroup `
        --job-execution-name $execName `
        --query "properties.status" -o tsv 2>$null
    Write-Host "[04] status after ${elapsed}s: $status" -ForegroundColor DarkGray
    if ($status -in @("Succeeded","Failed","Stopped")) { break }
}

if ($status -ne "Succeeded") {
    Write-Host "[04] WARNING: prompt-init finished with status '$status'." -ForegroundColor Yellow
    Write-Host "    Inspect logs with:" -ForegroundColor Yellow
    Write-Host "    az containerapp job execution show -n $PromptInitJob -g $ResourceGroup --job-execution-name $execName" -ForegroundColor Yellow
    throw "prompt-init did not succeed"
}

Write-Host "[04] DONE. Prompts registered in MLflow." -ForegroundColor Green
