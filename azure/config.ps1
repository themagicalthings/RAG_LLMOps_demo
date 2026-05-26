# Shared configuration for the Azure deploy scripts.
# Every numbered script dot-sources this file: `. $PSScriptRoot\config.ps1`
# Edit values here, NOT in the numbered scripts.

$ErrorActionPreference = "Stop"

# --- Resource naming ---------------------------------------------------------
$global:ResourceGroup  = "rag-llmops-rg"
$global:Location       = "eastus"

# ACR name must be globally unique, 5-50 lowercase alphanumeric.
$global:AcrName        = "ragllmops170510"

# Container Apps
$global:EnvName        = "rag-env"
$global:MlflowApp      = "rag-mlflow"
$global:BackendApp     = "rag-backend"
$global:PromptInitJob  = "rag-prompt-init"

# App Service (Streamlit frontend). Web app name must be globally unique.
$global:AspName        = "rag-asp"
$global:WebApp         = "rag-frontend-170510"

# --- Image names -------------------------------------------------------------
$global:BackendImage   = "rag-backend:v1"
$global:FrontendImage  = "rag-frontend:v1"

# --- Paths -------------------------------------------------------------------
# Build context = the rag/ source root that contains dockerfiles/, backend/, frontend/, knowledge_base/.
$global:RepoRoot       = (Resolve-Path "$PSScriptRoot\..").Path
$global:BuildContext   = Join-Path $RepoRoot "rag\src\rag"
$global:EnvFile        = Join-Path $BuildContext ".env"

# --- Derived (filled in by 01-acr.ps1 from `az acr credential show`) ---------
# These are sourced from .env by later scripts.
$global:AcrLoginServer = "$AcrName.azurecr.io"

# --- Helpers -----------------------------------------------------------------
function Assert-Cmd($cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Required command '$cmd' not found on PATH."
    }
}

function Assert-Path($path, $hint = "") {
    if (-not (Test-Path $path)) {
        throw "Required path not found: $path $hint"
    }
}

# Reads a KEY=VALUE pair from .env. Returns $null if absent.
function Get-EnvVar([string]$file, [string]$key) {
    if (-not (Test-Path $file)) { return $null }
    $line = Select-String -Path $file -Pattern "^$([regex]::Escape($key))=" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Line -split '=', 2)[1]
}

# Idempotently upserts KEY=VALUE in .env (creates file if missing).
function Set-EnvVar([string]$file, [string]$key, [string]$value) {
    if (-not (Test-Path $file)) {
        New-Item -ItemType File -Path $file -Force | Out-Null
    }
    $lines = @(Get-Content -Path $file -ErrorAction SilentlyContinue)
    $pattern = "^$([regex]::Escape($key))="
    $found = $false
    $new = foreach ($l in $lines) {
        if ($l -match $pattern) { $found = $true; "$key=$value" } else { $l }
    }
    if (-not $found) { $new += "$key=$value" }
    Set-Content -Path $file -Value $new -Encoding UTF8
}

Write-Host "[config] RG=$ResourceGroup  Region=$Location  ACR=$AcrName" -ForegroundColor DarkGray
Write-Host "[config] BuildContext=$BuildContext" -ForegroundColor DarkGray
