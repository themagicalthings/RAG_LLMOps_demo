# 01-acr.ps1 -- Create resource group + Azure Container Registry, capture creds.
#
# Idempotent: re-running upgrades nothing, just re-fetches creds and rewrites .env.
# Prerequisites: az CLI logged in (`az login`), Docker Desktop running.

. $PSScriptRoot\config.ps1

Assert-Cmd az
Assert-Cmd docker

# --- 1. Validate Azure login --------------------------------------------------
$sub = az account show --query "{name:name, id:id}" -o json 2>$null | ConvertFrom-Json
if (-not $sub) { throw "Not logged in to Azure. Run 'az login' first." }
Write-Host "[01] Subscription: $($sub.name) ($($sub.id))" -ForegroundColor Cyan

# --- 2. Ensure the containerapp extension is installed ------------------------
$hasExt = az extension show --name containerapp --query "name" -o tsv 2>$null
if (-not $hasExt) {
    Write-Host "[01] Installing 'containerapp' az extension..." -ForegroundColor Yellow
    az extension add --name containerapp --upgrade --only-show-errors | Out-Null
} else {
    Write-Host "[01] containerapp extension already installed." -ForegroundColor DarkGray
}

# --- 3. Register required resource providers (idempotent) ---------------------
foreach ($ns in @("Microsoft.App", "Microsoft.OperationalInsights", "Microsoft.ContainerRegistry", "Microsoft.Web")) {
    $state = az provider show --namespace $ns --query "registrationState" -o tsv 2>$null
    if ($state -ne "Registered") {
        Write-Host "[01] Registering provider $ns ..." -ForegroundColor Yellow
        az provider register --namespace $ns --only-show-errors | Out-Null
    }
}

# --- 4. Resource group --------------------------------------------------------
Write-Host "[01] Creating resource group '$ResourceGroup' in '$Location' ..." -ForegroundColor Cyan
az group create --name $ResourceGroup --location $Location --only-show-errors --output none

# --- 5. ACR -------------------------------------------------------------------
Write-Host "[01] Creating ACR '$AcrName' (Basic, admin-enabled) ..." -ForegroundColor Cyan
az acr create `
    --resource-group $ResourceGroup `
    --name $AcrName `
    --sku Basic `
    --admin-enabled true `
    --only-show-errors --output none

# --- 6. Capture admin credentials -> .env ------------------------------------
$creds = az acr credential show --name $AcrName -o json | ConvertFrom-Json
if (-not $creds) { throw "Could not retrieve ACR credentials for $AcrName" }

$acrUser = $creds.username
$acrPass = $creds.passwords[0].value
$acrServer = "$AcrName.azurecr.io"

Write-Host "[01] Writing ACR_* values to $EnvFile" -ForegroundColor Cyan
Set-EnvVar $EnvFile "ACR_NAME"          $AcrName
Set-EnvVar $EnvFile "ACR_LOGIN_SERVER"  $acrServer
Set-EnvVar $EnvFile "ACR_USERNAME"      $acrUser
Set-EnvVar $EnvFile "ACR_PASSWORD"      $acrPass

# --- 7. Login Docker to ACR (so 02-build-push can push) ----------------------
Write-Host "[01] Logging Docker into ACR ..." -ForegroundColor Cyan
az acr login --name $AcrName | Out-Null

Write-Host "[01] DONE. ACR ready: $acrServer" -ForegroundColor Green
