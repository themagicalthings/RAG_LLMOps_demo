# 05-smoke-test.ps1 -- End-to-end smoke test (same as imperative 07-smoke-test).

. $PSScriptRoot\config.ps1

$backendUrl  = Get-EnvVar $EnvFile "BACKEND_URL"
$frontendUrl = Get-EnvVar $EnvFile "FRONTEND_URL"
$mlflowUrl   = Get-EnvVar $EnvFile "MLFLOW_TRACKING_URI"

foreach ($p in @(
    @{n="BACKEND_URL";         v=$backendUrl},
    @{n="FRONTEND_URL";        v=$frontendUrl},
    @{n="MLFLOW_TRACKING_URI"; v=$mlflowUrl}
)) {
    if (-not $p.v) { throw "Missing $($p.n) in .env (run 03-deploy.ps1 first)" }
}

function Try-Http($name, $url, $maxTries = 30, $delaySec = 5) {
    for ($i = 1; $i -le $maxTries; $i++) {
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
            if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) {
                Write-Host "[05] $name OK ($($r.StatusCode)) after $i try/tries" -ForegroundColor Green
                return $r
            }
        } catch {
            Write-Host "[05] $name try ${i}/${maxTries}: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
        Start-Sleep -Seconds $delaySec
    }
    throw "$name never responded at $url"
}

$root = Try-Http "backend /" $backendUrl
Write-Host "[05] backend body: $($root.Content)" -ForegroundColor DarkGray
Try-Http "mlflow /"   $mlflowUrl   | Out-Null
Try-Http "frontend /" $frontendUrl | Out-Null

Write-Host "[05] Asking backend a real question ..." -ForegroundColor Cyan
$body = @{ prompt = "Which document mentions FastAPI?" } | ConvertTo-Json
$resp = Invoke-RestMethod -Uri "$backendUrl/rag/query" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 120
Write-Host "[05] answer:   $($resp.answer)"   -ForegroundColor Green
Write-Host "[05] filepath: $($resp.filepath)" -ForegroundColor Green

Write-Host ""
Write-Host "[05] DONE. Bicep-deployed stack is healthy." -ForegroundColor Green
Write-Host "  Frontend: $frontendUrl" -ForegroundColor Cyan
Write-Host "  Backend:  $backendUrl"  -ForegroundColor Cyan
Write-Host "  MLflow:   $mlflowUrl"   -ForegroundColor Cyan
