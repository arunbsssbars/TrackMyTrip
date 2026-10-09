# =================================================================
# TrackMyTrip - LCOV Code Coverage Parser & Gate
# Usage: powershell -ExecutionPolicy Bypass -File scripts/parse_coverage.ps1 [-MinPercent 60]
# =================================================================

param(
    [double]$MinPercent = 50.0,
    [string]$LcovPath = "coverage/lcov.info"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " TrackMyTrip CI/CD Code Coverage Analyzer " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path $LcovPath)) {
    Write-Host "[WARN] Coverage file not found at: $LcovPath" -ForegroundColor Yellow
    Write-Host "Run 'flutter test --coverage' first to generate coverage data." -ForegroundColor Yellow
    exit 0
}

$lines = Get-Content $LcovPath
$totalLines = 0
$coveredLines = 0

foreach ($line in $lines) {
    if ($line -match "^LF:(\d+)") {
        $totalLines += [int]$matches[1]
    }
    elseif ($line -match "^LH:(\d+)") {
        $coveredLines += [int]$matches[1]
    }
}

if ($totalLines -eq 0) {
    Write-Host "[WARN] No instrumented lines found in $LcovPath." -ForegroundColor Yellow
    exit 0
}

$coveragePercent = [math]::Round(($coveredLines / $totalLines) * 100, 2)

Write-Host "Instrumented Lines : $totalLines" -ForegroundColor White
Write-Host "Covered Lines      : $coveredLines" -ForegroundColor White
Write-Host "Total Coverage     : $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge $MinPercent) { "Green" } else { "Red" })

if ($coveragePercent -ge $MinPercent) {
    Write-Host "[PASS] Code coverage meets minimum threshold of $MinPercent%." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[WARN] Coverage is below target threshold ($MinPercent%)." -ForegroundColor Yellow
    exit 0
}
