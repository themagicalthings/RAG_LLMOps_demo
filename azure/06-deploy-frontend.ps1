# 06-deploy-frontend.ps1 -- Deploy Streamlit frontend on Azure App Service (Linux containers).

. $PSScriptRoot\config.ps1

$acrServer  = Get-EnvVar $EnvFile "ACR_LOGIN_SERVER"
$acrUser    = Get-EnvVar $EnvFile "ACR_USERNAME"
$acrPass    = Get-EnvVar $EnvFile "ACR_PASSWORD"
$backendUrl = Get-EnvVar $EnvFile "BACKEND_URL"

foreach ($pair in @(
    @{n="ACR_LOGIN_SERVER"; v=$acrServer},
    @{n="ACR_USERNAME";     v=$acrUser},
    @{n="ACR_PASSWORD";     v=$acrPass},
    @{n="BACKEND_URL";      v=$backendUrl}
)) {
    if (-not $pair.v) { throw "Missing $($pair.n) in $EnvFile (run 01 + 05 first)" }
}

$frontendTag = "$acrServer/$FrontendImage"

# --- 1. App Service plan (Linux, B1) ------------------------------------------
$planExists = az appservice plan show --name $AspName --resource-group $ResourceGroup --query "name" -o tsv 2>$null
if (-not $planExists) {
    Write-Host "[06] Creating Linux App Service plan '$AspName' (B1) ..." -ForegroundColor Cyan
    az appservice plan create `
        --name $AspName `
        --resource-group $ResourceGroup `
        --location $Location `
        --is-linux `
        --sku B1 `
        --only-show-errors --output none
} else {
    Write-Host "[06] App Service plan '$AspName' exists." -ForegroundColor DarkGray
}

# --- 2. Web App (container) ---------------------------------------------------
$webExists = az webapp show --name $WebApp --resource-group $ResourceGroup --query "name" -o tsv 2>$null
if (-not $webExists) {
    Write-Host "[06] Creating Web App '$WebApp' from container $frontendTag ..." -ForegroundColor Cyan
    az webapp create `
        --name $WebApp `
        --resource-group $ResourceGroup `
        --plan $AspName `
        --container-image-name $frontendTag `
        --container-registry-url "https://$acrServer" `
        --container-registry-user $acrUser `
        --container-registry-password $acrPass `
        --only-show-errors --output none
} else {
    Write-Host "[06] Web App exists, updating container image ..." -ForegroundColor Yellow
    az webapp config container set `
        --name $WebApp `
        --resource-group $ResourceGroup `
        --container-image-name $frontendTag `
        --container-registry-url "https://$acrServer" `
        --container-registry-user $acrUser `
        --container-registry-password $acrPass `
        --only-show-errors --output none
}

# --- 3. App settings: API_URL + WEBSITES_PORT --------------------------------
Write-Host "[06] Setting app settings (API_URL, WEBSITES_PORT=8501) ..." -ForegroundColor Cyan
az webapp config appsettings set `
    --name $WebApp `
    --resource-group $ResourceGroup `
    --settings "API_URL=$backendUrl" "WEBSITES_PORT=8501" `
    --only-show-errors --output none

# --- 4. Enable WebSockets + Always On ----------------------------------------
Write-Host "[06] Enabling WebSockets + AlwaysOn ..." -ForegroundColor Cyan
az webapp config set `
    --name $WebApp `
    --resource-group $ResourceGroup `
    --web-sockets-enabled true `
    --always-on true `
    --only-show-errors --output none

# --- 5. Restart so new settings take effect ----------------------------------
az webapp restart --name $WebApp --resource-group $ResourceGroup --only-show-errors --output none

$webUrl = "https://$(az webapp show --name $WebApp --resource-group $ResourceGroup --query "defaultHostName" -o tsv)"
Set-EnvVar $EnvFile "FRONTEND_URL" $webUrl

Write-Host "[06] DONE. Frontend URL: $webUrl" -ForegroundColor Green
