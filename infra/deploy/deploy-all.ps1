# deploy-all.ps1 -- Run every stage in order: bootstrap.bicep -> push -> main.bicep -> job -> smoke.

. $PSScriptRoot\config.ps1

$steps = @(
    "01-bootstrap.ps1",
    "02-build-push.ps1",
    "03-deploy.ps1",
    "04-prompt-init.ps1",
    "05-smoke-test.ps1"
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
