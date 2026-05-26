# 07-smoke-test.ps1 -- End-to-end smoke test of the deployed stack.

. $PSScriptRoot\config.ps1

$backendUrl  = Get-EnvVar $EnvFile "BACKEND_URL"
$frontendUrl = Get-EnvVar $EnvFile "FRONTEND_URL"
$mlflowUrl   = Get-EnvVar $EnvFile "MLFLOW_TRACKING_URI"

foreach ($pair in @(
    @{n="BACKEND_URL";          v=$backendUrl},
    @{n="FRONTEND_URL";         v=$frontendUrl},
    @{n="MLFLOW_TRACKING_URI";  v=$mlflowUrl}
)) {
    if (-not $pair.v) { throw "Missing $($pair.n) in .env (run prior scripts first)" }
}

function Try-Http($name, $url, $maxTries = 30, $delaySec = 5) {
    for ($i = 1; $i -le $maxTries; $i++) {
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
            if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) {
                Write-Host "[07] $name OK ($($r.StatusCode)) after $i try/tries" -ForegroundColor Green
                return $r
            }
        } catch {
            Write-Host "[07] $name try ${i}/${maxTries}: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
        Start-Sleep -Seconds $delaySec
    }
    throw "$name never responded successfully at $url"
}

# 1. Backend root
$root = Try-Http "backend /" $backendUrl
Write-Host "[07] backend body: $($root.Content)" -ForegroundColor DarkGray

# 2. MLflow root
Try-Http "mlflow /" $mlflowUrl | Out-Null

# 3. Frontend root (Streamlit serves HTML even before connecting)
Try-Http "frontend /" $frontendUrl | Out-Null

# 4. End-to-end RAG query through the backend
Write-Host "[07] Asking backend a real question ..." -ForegroundColor Cyan
$body = @{ prompt = "Which document mentions FastAPI?" } | ConvertTo-Json
try {
    $resp = Invoke-RestMethod -Uri "$backendUrl/rag/query" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 120
    Write-Host "[07] answer:   $($resp.answer)" -ForegroundColor Green
    Write-Host "[07] filepath: $($resp.filepath)" -ForegroundColor Green
} catch {
    throw "RAG query failed: $($_.Exception.Message)"
}

Write-Host "[07] DONE. Stack is healthy." -ForegroundColor Green
Write-Host ""
Write-Host "  Frontend: $frontendUrl" -ForegroundColor Cyan
Write-Host "  Backend:  $backendUrl" -ForegroundColor Cyan
Write-Host "  MLflow:   $mlflowUrl"  -ForegroundColor Cyan
