# deploy-all.ps1 -- One-shot orchestrator. Runs every numbered step in order.
#
# Each step is idempotent; safe to re-run if one fails.
# Stops on first failure ($ErrorActionPreference = "Stop" in config.ps1).

. $PSScriptRoot\config.ps1

$steps = @(
    "01-acr.ps1",
    "02-build-push.ps1",
    "03-deploy-mlflow.ps1",
    "04-prompt-init.ps1",
    "05-deploy-backend.ps1",
    "06-deploy-frontend.ps1",
    "07-smoke-test.ps1"
)

$start = Get-Date
foreach ($s in $steps) {
    Write-Host ""
    Write-Host "================ $s ================" -ForegroundColor Magenta
    & (Join-Path $PSScriptRoot $s)
    if ($LASTEXITCODE -ne 0) { throw "$s exited with code $LASTEXITCODE" }
}
$elapsed = (Get-Date) - $start
Write-Host ""
Write-Host "All steps completed in $([int]$elapsed.TotalMinutes)m $([int]$elapsed.Seconds)s" -ForegroundColor Green
