# 04-prompt-init.ps1 -- Start the Container Apps Job that registers MLflow prompts, wait for completion.
#
# Bicep declared the Job (in main.bicep). Bicep CANNOT trigger Job executions.
# This script is the imperative bridge -- start + poll status.

. $PSScriptRoot\config.ps1

Write-Host "[04] Starting Container Apps Job '$PromptInitJob' ..." -ForegroundColor Cyan
$exec = az containerapp job start --name $PromptInitJob --resource-group $ResourceGroup -o json | ConvertFrom-Json
$execName = $exec.name
Write-Host "[04] Execution: $execName" -ForegroundColor DarkGray

# Poll up to ~10 minutes for completion.
# First-run cold start can take 4-7 min (replica scheduling + image pull
# + Python boot + mlflow import + actual prompt registration).
$timeoutSec = 600
$elapsed = 0
$status = "Running"
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
