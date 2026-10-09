# TrackMyTrip Local DevOps Pre-Push Verification Script (PowerShell)
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   TrackMyTrip DevOps Pre-Push Quality Gate" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "`n[1/4] Running Static Analysis and Lint..." -ForegroundColor Yellow
flutter analyze lib --fatal-infos
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Static analysis failed! Please fix issues before pushing." -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] Static analysis passed with zero issues." -ForegroundColor Green

Write-Host "`n[2/4] Running Super Admin and Resilience Tests..." -ForegroundColor Yellow
flutter test test/super_admin_test.dart test/twenty_loop_features_resilience_test.dart
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Unit tests failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] Core unit tests passed." -ForegroundColor Green

Write-Host "`n[3/4] Running DevOps Telemetry and Schema Verification Tests..." -ForegroundColor Yellow
flutter test test/devops_pipeline_and_admin_telemetry_test.dart
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] DevOps telemetry tests failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] DevOps telemetry tests passed." -ForegroundColor Green

Write-Host "`n[4/4] Auditing Tracked Files for Secrets..." -ForegroundColor Yellow
$suspicious = git ls-files | Select-String -Pattern '\.env$|\.env\.production$|key\.properties$|\.jks$|\.keystore$|google-services\.json\.secret'
if ($suspicious) {
    Write-Host "[FAIL] Sensitive files detected in Git tree!" -ForegroundColor Red
    $suspicious | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "[PASS] Zero sensitive files detected in Git." -ForegroundColor Green

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "[SUCCESS] All DevOps Pre-Push Gates Passed!" -ForegroundColor Green
Write-Host "Ready to commit and push to GitHub." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
