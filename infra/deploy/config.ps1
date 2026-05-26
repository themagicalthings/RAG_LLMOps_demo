# Shared configuration for the Bicep deploy wrappers.
# Same variables as the imperative `azure/config.ps1`, kept in sync.

$ErrorActionPreference = "Stop"

# --- Naming (must match what the Bicep parameter names expect) ---------------
$global:ResourceGroup    = "rag-llmops-rg"
$global:Location         = "eastus"
$global:AcrName          = "ragllmops170510"
$global:EnvName          = "rag-env"
$global:MlflowApp        = "rag-mlflow"
$global:BackendApp       = "rag-backend"
$global:PromptInitJob    = "rag-prompt-init"
$global:FrontendApp      = "rag-frontend"

$global:BackendImageTag  = "v1"
$global:FrontendImageTag = "v1"

# --- Paths -------------------------------------------------------------------
$global:InfraRoot       = (Resolve-Path "$PSScriptRoot\..").Path
$global:RepoRoot        = (Resolve-Path "$PSScriptRoot\..\..").Path
$global:BuildContext    = Join-Path $RepoRoot "rag\src\rag"
$global:EnvFile         = Join-Path $BuildContext ".env"

$global:BootstrapBicep  = Join-Path $InfraRoot "bootstrap.bicep"
$global:MainBicep       = Join-Path $InfraRoot "main.bicep"

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

function Get-EnvVar([string]$file, [string]$key) {
    if (-not (Test-Path $file)) { return $null }
    $line = Select-String -Path $file -Pattern "^$([regex]::Escape($key))=" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Line -split '=', 2)[1]
}

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

Write-Host "[config] RG=$ResourceGroup Region=$Location ACR=$AcrName" -ForegroundColor DarkGray
Write-Host "[config] InfraRoot=$InfraRoot" -ForegroundColor DarkGray
