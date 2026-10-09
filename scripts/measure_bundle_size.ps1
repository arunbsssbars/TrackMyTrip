# =================================================================
# TrackMyTrip - Release Binary & Bundle Size Budget Guard
# Usage: powershell -ExecutionPolicy Bypass -File scripts/measure_bundle_size.ps1 [-FilePath "build/app/outputs/flutter-apk/app-release.apk"] [-MaxMb 50.0]
# =================================================================

param(
    [string]$FilePath = "build/app/outputs/flutter-apk/app-release.apk",
    [double]$MaxMb = 50.0
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " TrackMyTrip CI/CD Bundle Size Analyzer   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path $FilePath)) {
    Write-Host "[NOTICE] Binary artifact not found at: $FilePath (skipped in non-build context)" -ForegroundColor Yellow
    exit 0
}

$fileItem = Get-Item $FilePath
$bytes = $fileItem.Length
$sizeMb = [math]::Round($bytes / (1024 * 1024), 2)
$budgetUsagePercent = [math]::Round(($sizeMb / $MaxMb) * 100, 1)

Write-Host "Binary File       : $($fileItem.Name)" -ForegroundColor White
Write-Host "Size (MB)         : $sizeMb MB" -ForegroundColor White
Write-Host "Budget Limit      : $MaxMb MB" -ForegroundColor White
Write-Host "Budget Consumed   : $budgetUsagePercent%" -ForegroundColor $(if ($sizeMb -le $MaxMb) { "Green" } else { "Red" })

if ($sizeMb -le $MaxMb) {
    Write-Host "[PASS] Binary size is within budget threshold ($sizeMb MB <= $MaxMb MB)." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[ERROR] Binary size EXCEEDS budget limit ($sizeMb MB > $MaxMb MB)!" -ForegroundColor Red
    exit 1
}
