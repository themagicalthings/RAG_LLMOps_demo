# 02-build-push.ps1 -- Build amd64 backend + frontend images and push to ACR.
#
# Requires: 01-acr.ps1 already run (.env has ACR_LOGIN_SERVER, ACR_USERNAME, ACR_PASSWORD).
# Requires: rag\src\rag\knowledge_base\articles.lance exists (run ingestion first).

. $PSScriptRoot\config.ps1

Assert-Cmd docker

$acrServer = Get-EnvVar $EnvFile "ACR_LOGIN_SERVER"
$acrUser   = Get-EnvVar $EnvFile "ACR_USERNAME"
$acrPass   = Get-EnvVar $EnvFile "ACR_PASSWORD"
if (-not $acrServer -or -not $acrUser -or -not $acrPass) {
    throw "ACR_* values missing from $EnvFile. Run 01-acr.ps1 first."
}

# Verify build context + ingested vector DB exist.
Assert-Path $BuildContext "(repo source root)"
Assert-Path (Join-Path $BuildContext "dockerfiles\backend.dockerfile")
Assert-Path (Join-Path $BuildContext "dockerfiles\frontend.dockerfile")
Assert-Path (Join-Path $BuildContext "knowledge_base\articles.lance") "-- run 'python -m rag.setup.ingestion' before building"

# --- Docker login -------------------------------------------------------------
Write-Host "[02] Docker login to $acrServer ..." -ForegroundColor Cyan
$acrPass | docker login $acrServer --username $acrUser --password-stdin | Out-Null
if ($LASTEXITCODE -ne 0) { throw "docker login failed" }

# --- Buildx builder -----------------------------------------------------------
# Ensure we have a buildx builder that supports cross-platform builds.
$builder = "rag-builder"
$exists = docker buildx ls --format "{{.Name}}" 2>$null | Where-Object { $_ -eq $builder }
if (-not $exists) {
    Write-Host "[02] Creating buildx builder '$builder' ..." -ForegroundColor Yellow
    docker buildx create --name $builder --use | Out-Null
} else {
    docker buildx use $builder | Out-Null
}

# --- Build + push backend -----------------------------------------------------
$backendTag = "$acrServer/$BackendImage"
Write-Host "[02] Building+pushing backend image: $backendTag" -ForegroundColor Cyan
docker buildx build `
    --platform linux/amd64 `
    --file (Join-Path $BuildContext "dockerfiles\backend.dockerfile") `
    --tag $backendTag `
    --push `
    $BuildContext
if ($LASTEXITCODE -ne 0) { throw "backend image build/push failed" }

# --- Build + push frontend ----------------------------------------------------
$frontendTag = "$acrServer/$FrontendImage"
Write-Host "[02] Building+pushing frontend image: $frontendTag" -ForegroundColor Cyan
docker buildx build `
    --platform linux/amd64 `
    --file (Join-Path $BuildContext "dockerfiles\frontend.dockerfile") `
    --tag $frontendTag `
    --push `
    $BuildContext
if ($LASTEXITCODE -ne 0) { throw "frontend image build/push failed" }

Write-Host "[02] DONE. Images in ACR:" -ForegroundColor Green
az acr repository list --name $AcrName -o tsv
