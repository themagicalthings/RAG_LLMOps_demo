# 03-deploy.ps1 -- Resource-group-scope Bicep deploy (env + MLflow + job + backend + frontend).
#
# Reads ACR creds + API keys from .env, hands them to main.bicep as secure parameters,
# and captures the output URLs back into .env for the smoke test.

. $PSScriptRoot\config.ps1

Assert-Path $MainBicep

# --- Pull required values from .env ------------------------------------------
$acrUser   = Get-EnvVar $EnvFile "ACR_USERNAME"
$acrPass   = Get-EnvVar $EnvFile "ACR_PASSWORD"
$cohere    = Get-EnvVar $EnvFile "COHERE_API_KEY"
$openrouter= Get-EnvVar $EnvFile "OPENROUTER_API_KEY"

foreach ($p in @(
    @{n="ACR_USERNAME";        v=$acrUser},
    @{n="ACR_PASSWORD";        v=$acrPass},
    @{n="COHERE_API_KEY";      v=$cohere},
    @{n="OPENROUTER_API_KEY";  v=$openrouter}
)) {
    if (-not $p.v) { throw "Missing $($p.n) in $EnvFile" }
}

# --- Deploy main.bicep --------------------------------------------------------
$deploymentName = "rag-main-$(Get-Date -Format yyyyMMddHHmmss)"
Write-Host "[03] Running az deployment group create '$deploymentName' ..." -ForegroundColor Cyan

# All non-secret parameters are passed as plain values; @secure() ones via
# --parameters key=value (still visible to local processes briefly, but never
# logged by ARM and never written to disk).
$result = az deployment group create `
    --name $deploymentName `
    --resource-group $ResourceGroup `
    --template-file $MainBicep `
    --parameters `
        location=$Location `
        acrName=$AcrName `
        acrUsername=$acrUser `
        acrPassword=$acrPass `
        envName=$EnvName `
        mlflowAppName=$MlflowApp `
        backendAppName=$BackendApp `
        promptInitJobName=$PromptInitJob `
        frontendAppName=$FrontendApp `
        backendImageTag=$BackendImageTag `
        frontendImageTag=$FrontendImageTag `
        cohereApiKey=$cohere `
        openrouterApiKey=$openrouter `
    --only-show-errors `
    -o json | ConvertFrom-Json

if (-not $result) { throw "main deployment failed" }

# --- Capture outputs back to .env --------------------------------------------
$out = $result.properties.outputs
$mlflowUrl   = $out.mlflowUrl.value
$backendUrl  = $out.backendUrl.value
$frontendUrl = $out.frontendUrl.value

Write-Host "[03] mlflowUrl  = $mlflowUrl"   -ForegroundColor Green
Write-Host "[03] backendUrl = $backendUrl"  -ForegroundColor Green
Write-Host "[03] frontendUrl= $frontendUrl" -ForegroundColor Green

Set-EnvVar $EnvFile "MLFLOW_TRACKING_URI" $mlflowUrl
Set-EnvVar $EnvFile "BACKEND_URL"         $backendUrl
Set-EnvVar $EnvFile "FRONTEND_URL"        $frontendUrl

Write-Host "[03] DONE. Stack provisioned via Bicep." -ForegroundColor Green
