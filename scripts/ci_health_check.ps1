# =================================================================
# TrackMyTrip - Post-Deployment CI/CD Canary Health Check
# Usage: powershell -ExecutionPolicy Bypass -File scripts/ci_health_check.ps1
# =================================================================

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " TrackMyTrip CI/CD Canary Health Probe    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$passedChecks = 0
$totalChecks = 2

# Check 1: OpenStreetMap Tile Server Probe
Write-Host "Probing OSM Tile CDN (https://tile.openstreetmap.org/0/0/0.png)..." -NoNewline
try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $res = Invoke-WebRequest -Uri "https://tile.openstreetmap.org/0/0/0.png" -Method Get -TimeoutSec 5 -UseBasicParsing -UserAgent "TrackMyTrip-CI-Canary"
    $sw.Stop()
    if ($res.StatusCode -eq 200) {
        Write-Host " [ONLINE] ($($sw.ElapsedMilliseconds)ms)" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host " [DEGRADED] (HTTP $($res.StatusCode))" -ForegroundColor Yellow
    }
} catch {
    Write-Host " [FAILED] ($($_.Exception.Message))" -ForegroundColor Red
}

# Check 2: Live FX Exchange Rates Endpoint Probe
Write-Host "Probing Live FX Endpoint (https://open.er-api.com/v6/latest/INR)..." -NoNewline
try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $res = Invoke-WebRequest -Uri "https://open.er-api.com/v6/latest/INR" -Method Get -TimeoutSec 5 -UseBasicParsing
    $sw.Stop()
    if ($res.StatusCode -eq 200) {
        Write-Host " [ONLINE] ($($sw.ElapsedMilliseconds)ms)" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host " [DEGRADED] (HTTP $($res.StatusCode))" -ForegroundColor Yellow
    }
} catch {
    Write-Host " [FAILED] ($($_.Exception.Message))" -ForegroundColor Red
}

$score = [math]::Round(($passedChecks / $totalChecks) * 100, 0)
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Canary Health Score: $score/100" -ForegroundColor $(if ($score -ge 50) { "Green" } else { "Red" })

if ($score -ge 50) {
    Write-Host "[SUCCESS] Canary probe confirmed service availability." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[CRITICAL] Canary probe failed - Automated Rollback Recommended!" -ForegroundColor Red
    exit 1
}
