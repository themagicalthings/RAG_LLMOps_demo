# teardown.ps1 -- Delete the entire resource group (asks for confirmation).

. $PSScriptRoot\config.ps1

Write-Host "About to DELETE resource group '$ResourceGroup' and ALL resources inside it." -ForegroundColor Red
$answer = Read-Host "Type the resource group name to confirm"
if ($answer -ne $ResourceGroup) {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 1
}

Write-Host "Deleting resource group (no-wait) ..." -ForegroundColor Cyan
az group delete --name $ResourceGroup --yes --no-wait
Write-Host "Kicked off in background. Check with: az group show --name $ResourceGroup" -ForegroundColor Green
