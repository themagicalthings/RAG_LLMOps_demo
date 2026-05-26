# 05-deploy-backend.ps1 -- Deploy FastAPI backend Container App.
#
# Secrets: COHERE_API_KEY, OPENROUTER_API_KEY (sourced from local .env).
# Env: MLFLOW_TRACKING_URI (from .env, set by 03), GIT_PYTHON_REFRESH=quiet.

. $PSScriptRoot\config.ps1

$acrServer = Get-EnvVar $EnvFile "ACR_LOGIN_SERVER"
$acrUser   = Get-EnvVar $EnvFile "ACR_USERNAME"
$acrPass   = Get-EnvVar $EnvFile "ACR_PASSWORD"
$mlflowUrl = Get-EnvVar $EnvFile "MLFLOW_TRACKING_URI"
$cohere    = Get-EnvVar $EnvFile "COHERE_API_KEY"
$openrouter= Get-EnvVar $EnvFile "OPENROUTER_API_KEY"

foreach ($pair in @(
    @{n="ACR_LOGIN_SERVER";    v=$acrServer},
    @{n="ACR_USERNAME";        v=$acrUser},
    @{n="ACR_PASSWORD";        v=$acrPass},
    @{n="MLFLOW_TRACKING_URI"; v=$mlflowUrl},
    @{n="COHERE_API_KEY";      v=$cohere},
    @{n="OPENROUTER_API_KEY";  v=$openrouter}
)) {
    if (-not $pair.v) { throw "Missing $($pair.n) in $EnvFile" }
}

$backendTag = "$acrServer/$BackendImage"

$appExists = az containerapp show --name $BackendApp --resource-group $ResourceGroup --query "name" -o tsv 2>$null

if (-not $appExists) {
    Write-Host "[05] Creating backend container app '$BackendApp' ..." -ForegroundColor Cyan
    az containerapp create `
        --name $BackendApp `
        --resource-group $ResourceGroup `
        --environment $EnvName `
        --image $backendTag `
        --target-port 8000 `
        --ingress external `
        --cpu 1.0 --memory 2.0Gi `
        --min-replicas 1 --max-replicas 1 `
        --registry-server $acrServer `
        --registry-username $acrUser `
        --registry-password $acrPass `
        --secrets "cohere-api-key=$cohere" "openrouter-api-key=$openrouter" `
        --env-vars `
            "COHERE_API_KEY=secretref:cohere-api-key" `
            "OPENROUTER_API_KEY=secretref:openrouter-api-key" `
            "MLFLOW_TRACKING_URI=$mlflowUrl" `
            "GIT_PYTHON_REFRESH=quiet" `
        --only-show-errors --output none
} else {
    Write-Host "[05] Backend exists, updating image + secrets + env ..." -ForegroundColor Yellow
    az containerapp secret set `
        --name $BackendApp --resource-group $ResourceGroup `
        --secrets "cohere-api-key=$cohere" "openrouter-api-key=$openrouter" `
        --only-show-errors --output none
    az containerapp update `
        --name $BackendApp `
        --resource-group $ResourceGroup `
        --image $backendTag `
        --set-env-vars `
            "COHERE_API_KEY=secretref:cohere-api-key" `
            "OPENROUTER_API_KEY=secretref:openrouter-api-key" `
            "MLFLOW_TRACKING_URI=$mlflowUrl" `
            "GIT_PYTHON_REFRESH=quiet" `
        --only-show-errors --output none
}

$backendFqdn = az containerapp show --name $BackendApp --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv
if (-not $backendFqdn) { throw "Could not resolve backend FQDN" }
$backendUrl = "https://$backendFqdn"

Set-EnvVar $EnvFile "BACKEND_URL" $backendUrl

Write-Host "[05] DONE. Backend URL: $backendUrl" -ForegroundColor Green
