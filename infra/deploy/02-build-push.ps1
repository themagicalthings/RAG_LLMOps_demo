# 02-build-push.ps1 -- Build amd64 backend + frontend images and push to ACR.
#
# Identical to the imperative azure/02-build-push.ps1 -- Docker is not an ARM
# resource so Bicep cannot do this step.

. $PSScriptRoot\config.ps1

Assert-Cmd docker

$acrServer = Get-EnvVar $EnvFile "ACR_LOGIN_SERVER"
$acrUser   = Get-EnvVar $EnvFile "ACR_USERNAME"
$acrPass   = Get-EnvVar $EnvFile "ACR_PASSWORD"
if (-not $acrServer -or -not $acrUser -or -not $acrPass) {
    throw "ACR_* values missing from $EnvFile. Run 01-bootstrap.ps1 first."
}

Assert-Path $BuildContext
Assert-Path (Join-Path $BuildContext "dockerfiles\backend.dockerfile")
Assert-Path (Join-Path $BuildContext "dockerfiles\frontend.dockerfile")
Assert-Path (Join-Path $BuildContext "knowledge_base\articles.lance") "-- run 'python -m rag.setup.ingestion' before building"

# Docker login
Write-Host "[02] Docker login to $acrServer ..." -ForegroundColor Cyan
$acrPass | docker login $acrServer --username $acrUser --password-stdin | Out-Null
if ($LASTEXITCODE -ne 0) { throw "docker login failed" }

# Builder
$builder = "rag-builder"
$exists = docker buildx ls --format "{{.Name}}" 2>$null | Where-Object { $_ -eq $builder }
if (-not $exists) {
    docker buildx create --name $builder --use | Out-Null
} else {
    docker buildx use $builder | Out-Null
}

# Backend
$backendTag = "$acrServer/rag-backend:$BackendImageTag"
Write-Host "[02] Building+pushing $backendTag" -ForegroundColor Cyan
docker buildx build `
    --platform linux/amd64 `
    --file (Join-Path $BuildContext "dockerfiles\backend.dockerfile") `
    --tag $backendTag `
    --push `
    $BuildContext
if ($LASTEXITCODE -ne 0) { throw "backend build/push failed" }

# Frontend
$frontendTag = "$acrServer/rag-frontend:$FrontendImageTag"
Write-Host "[02] Building+pushing $frontendTag" -ForegroundColor Cyan
docker buildx build `
    --platform linux/amd64 `
    --file (Join-Path $BuildContext "dockerfiles\frontend.dockerfile") `
    --tag $frontendTag `
    --push `
    $BuildContext
if ($LASTEXITCODE -ne 0) { throw "frontend build/push failed" }

Write-Host "[02] DONE. ACR contents:" -ForegroundColor Green
az acr repository list --name $AcrName -o tsv
