# TrackMyTrip DevSecOps Git Hook Installer (PowerShell)
Write-Host "[DevSecOps] Configuring Git hooks path to .githooks..." -ForegroundColor Cyan

git config core.hooksPath .githooks

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Git hooks configured successfully!" -ForegroundColor Green
    Write-Host "Pre-commit secret blocker is now actively protecting your commits." -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to configure Git hooks path." -ForegroundColor Red
    exit 1
}
