# 03-deploy-mlflow.ps1 -- Container Apps environment + MLflow tracking server.
#
# Uses the public ghcr.io/mlflow/mlflow:latest image (no ACR required).
# Storage is EPHEMERAL by design (demo). Experiment history is wiped on restart.
# To persist: add an Azure Files mount and pass --backend-store-uri pointing there.

. $PSScriptRoot\config.ps1

# --- 1. Container Apps environment -------------------------------------------
$envExists = az containerapp env show --name $EnvName --resource-group $ResourceGroup --query "name" -o tsv 2>$null
if (-not $envExists) {
    Write-Host "[03] Creating Container Apps environment '$EnvName' ..." -ForegroundColor Cyan
    az containerapp env create `
        --name $EnvName `
        --resource-group $ResourceGroup `
        --location $Location `
        --only-show-errors --output none
} else {
    Write-Host "[03] Container Apps env '$EnvName' already exists." -ForegroundColor DarkGray
}

# --- 2. MLflow Container App --------------------------------------------------
# MLflow listens on 5000 inside the container; ingress exposes via 443 externally.
$mlflowImage = "ghcr.io/mlflow/mlflow:latest"

# Override the container's default command so we get a server with CORS open
# and an explicit sqlite backend store (ephemeral on demo).
$mlflowCmd  = "mlflow"
$mlflowArgs = "server --host 0.0.0.0 --port 5000 --backend-store-uri sqlite:////mlflow/mlflow.db"

$appExists = az containerapp show --name $MlflowApp --resource-group $ResourceGroup --query "name" -o tsv 2>$null
if (-not $appExists) {
    Write-Host "[03] Creating MLflow container app '$MlflowApp' ..." -ForegroundColor Cyan
    az containerapp create `
        --name $MlflowApp `
        --resource-group $ResourceGroup `
        --environment $EnvName `
        --image $mlflowImage `
        --target-port 5000 `
        --ingress external `
        --cpu 0.5 --memory 1.0Gi `
        --min-replicas 1 --max-replicas 1 `
        --env-vars "MLFLOW_SERVER_CORS_ALLOWED_ORIGINS=*" `
        --command $mlflowCmd `
        --args "server" "--host" "0.0.0.0" "--port" "5000" "--backend-store-uri" "sqlite:////mlflow/mlflow.db" "--allowed-hosts" "*" `
        --only-show-errors --output none
} else {
    Write-Host "[03] MLflow app exists, updating image + env ..." -ForegroundColor Yellow
    az containerapp update `
        --name $MlflowApp `
        --resource-group $ResourceGroup `
        --image $mlflowImage `
        --set-env-vars "MLFLOW_SERVER_CORS_ALLOWED_ORIGINS=*" `
        --only-show-errors --output none
}

# --- 3. Resolve public URL ----------------------------------------------------
$mlflowFqdn = az containerapp show --name $MlflowApp --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv
if (-not $mlflowFqdn) { throw "Could not resolve MLflow FQDN" }
$mlflowUrl = "https://$mlflowFqdn"

Write-Host "[03] MLflow URL: $mlflowUrl" -ForegroundColor Green
Set-EnvVar $EnvFile "MLFLOW_TRACKING_URI" $mlflowUrl

Write-Host "[03] DONE. (Saved MLFLOW_TRACKING_URI to .env)" -ForegroundColor Green
