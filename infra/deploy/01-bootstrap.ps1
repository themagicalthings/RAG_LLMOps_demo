# 01-bootstrap.ps1 -- Subscription-scope deploy: RG + ACR.
#
# Uses bootstrap.bicep. After it runs, captures ACR admin creds into .env so
# the build/push step and main.bicep can authenticate.

. $PSScriptRoot\config.ps1

Assert-Cmd az
Assert-Cmd docker
Assert-Path $BootstrapBicep

# --- 1. Validate Azure login --------------------------------------------------
$sub = az account show --query "{name:name, id:id}" -o json 2>$null | ConvertFrom-Json
if (-not $sub) { throw "Not logged in to Azure. Run 'az login' first." }
Write-Host "[01] Subscription: $($sub.name) ($($sub.id))" -ForegroundColor Cyan

# --- 1b. Bicep CLI version check ---------------------------------------------
# v0.43.x has a NullRef bug on Windows when compiling files with module refs.
# Pin to v0.32.4 (or any v0.30.x-0.34.x stable line).
$bicepRaw = az bicep version 2>$null
if ($bicepRaw -match '0\.43\.') {
    Write-Host "[01] Bicep $bicepRaw is buggy on Windows. Downgrading to v0.32.4 ..." -ForegroundColor Yellow
    az bicep install --version v0.32.4 --only-show-errors | Out-Null
}

# --- 2. Ensure containerapp extension installed (main.bicep needs it later) --
$hasExt = az extension show --name containerapp --query "name" -o tsv 2>$null
if (-not $hasExt) {
    Write-Host "[01] Installing 'containerapp' az extension..." -ForegroundColor Yellow
    az extension add --name containerapp --upgrade --only-show-errors | Out-Null
}

# --- 3. Register required providers (idempotent) -----------------------------
foreach ($ns in @("Microsoft.App","Microsoft.OperationalInsights","Microsoft.ContainerRegistry","Microsoft.Web")) {
    $state = az provider show --namespace $ns --query "registrationState" -o tsv 2>$null
    if ($state -ne "Registered") {
        Write-Host "[01] Registering provider $ns ..." -ForegroundColor Yellow
        az provider register --namespace $ns --only-show-errors | Out-Null
    }
}

# --- 4. Deploy bootstrap.bicep (creates RG + ACR) ----------------------------
$deploymentName = "rag-bootstrap-$(Get-Date -Format yyyyMMddHHmmss)"
Write-Host "[01] Running az deployment sub create '$deploymentName' ..." -ForegroundColor Cyan
$result = az deployment sub create `
    --name $deploymentName `
    --location $Location `
    --template-file $BootstrapBicep `
    --parameters location=$Location resourceGroupName=$ResourceGroup acrName=$AcrName `
    --only-show-errors `
    -o json | ConvertFrom-Json
if (-not $result) { throw "Bootstrap deployment failed" }

$acrLoginServer = $result.properties.outputs.acrLoginServer.value
Write-Host "[01] ACR login server: $acrLoginServer" -ForegroundColor Green

# --- 5. Capture ACR admin credentials -> .env --------------------------------
$creds = az acr credential show --name $AcrName -o json | ConvertFrom-Json
if (-not $creds) { throw "Could not retrieve ACR credentials" }
Set-EnvVar $EnvFile "ACR_NAME"         $AcrName
Set-EnvVar $EnvFile "ACR_LOGIN_SERVER" $acrLoginServer
Set-EnvVar $EnvFile "ACR_USERNAME"     $creds.username
Set-EnvVar $EnvFile "ACR_PASSWORD"     $creds.passwords[0].value

# --- 6. Docker login (so 02-build-push can push) -----------------------------
Write-Host "[01] Logging Docker into ACR ..." -ForegroundColor Cyan
az acr login --name $AcrName | Out-Null

Write-Host "[01] DONE. RG + ACR provisioned via Bicep." -ForegroundColor Green
